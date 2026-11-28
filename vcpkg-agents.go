package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	copilot "github.com/microsoft/copilot-sdk/go/v2"
	"github.com/microsoft/copilot-sdk/go/v2/rpc"
	"io"
	"log/slog"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"reflect"
	"regexp"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/google/jsonschema-go/jsonschema"
)

type multiFlag []string

func (values *multiFlag) String() string {
	return strings.Join(*values, string(os.PathListSeparator))
}

func (values *multiFlag) Set(value string) error {
	*values = append(*values, value)
	return nil
}

type Options struct {
	Prompt          string
	Model           string
	Verbose         bool
	OverlayPorts    []string
	OverlayTriplets []string
	BuildtreesRoot  string
	PackagesRoot    string
	InstallRoot     string
	ManifestRoot    string
	VcpkgRoot       string
	LogRoot         string
	Write           []string
	MaxPortCycles   int
	MaxTripletEdits int
	EnableSandbox   bool
}

func ParseOptions(args []string) (Options, error) {
	var options Options
	var overlays, overlayTriplets, writes multiFlag
	fs := flag.NewFlagSet("vcpkg-agents", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	fs.StringVar(&options.Prompt, "prompt", "", "prompt to drive the team (required)")
	fs.StringVar(&options.Model, "model", defaultModel, "single Copilot model used by all members")
	fs.BoolVar(&options.Verbose, "verbose", false, "enable DEBUG logging")
	fs.Var(&overlays, "overlay-ports", "explicit overlay ports folder; repeatable")
	fs.Var(&overlayTriplets, "overlay-triplets", "explicit overlay triplets folder; repeatable")
	fs.StringVar(&options.BuildtreesRoot, "x-buildtrees-root", "", "designated vcpkg buildtrees root")
	fs.StringVar(&options.PackagesRoot, "x-packages-root", "", "designated vcpkg packages root")
	fs.StringVar(&options.InstallRoot, "x-install-root", "", "designated vcpkg installed root")
	fs.StringVar(&options.ManifestRoot, "x-manifest-root", "", "manifest folder")
	fs.StringVar(&options.VcpkgRoot, "vcpkg-root", "", "vcpkg root")
	fs.StringVar(&options.LogRoot, "log-dir", "", "parent directory for retained command logs")
	fs.Var(&writes, "write", "write scope: ports,triplets,versions,manifest,overlays,create-overlays,commit; repeatable")
	fs.IntVar(&options.MaxPortCycles, "max-port-cycles", 3, "maximum failed cycles per port")
	fs.IntVar(&options.MaxTripletEdits, "max-triplet-edits", 1, "maximum triplet edits per triplet")
	fs.BoolVar(&options.EnableSandbox, "sandbox", false, "enable the experimental Copilot OS sandbox")
	if err := fs.Parse(args); err != nil {
		return Options{}, err
	}
	if strings.TrimSpace(options.Prompt) == "" {
		return Options{}, errors.New("--prompt is required")
	}
	if options.MaxPortCycles < 1 || options.MaxTripletEdits < 1 {
		return Options{}, errors.New("cycle and triplet-edit limits must be positive")
	}
	options.OverlayPorts = append([]string(nil), overlays...)
	options.OverlayTriplets = append([]string(nil), overlayTriplets...)
	for _, value := range writes {
		for _, part := range strings.Split(value, ",") {
			part = strings.TrimSpace(part)
			if part != "" {
				options.Write = append(options.Write, part)
			}
		}
	}
	allowedWriteScopes := map[string]bool{"ports": true, "triplets": true, "versions": true, "manifest": true, "overlays": true, "create-overlays": true, "commit": true}
	for _, scope := range options.Write {
		if !allowedWriteScopes[scope] {
			return Options{}, fmt.Errorf("unknown --write scope %q", scope)
		}
	}
	return options, nil
}
func SetupLogging(output io.Writer, verbose bool) {
	level := slog.LevelInfo
	if verbose {
		level = slog.LevelDebug
	}
	slog.SetDefault(slog.New(slog.NewTextHandler(output, &slog.HandlerOptions{Level: level})))
}

type VariableStatus struct {
	Name      string `json:"name"`
	Set       bool   `json:"set"`
	Ready     bool   `json:"ready"`
	Secret    bool   `json:"secret,omitempty"`
	Summary   string `json:"summary,omitempty"`
	Blocker   bool   `json:"blocker,omitempty"`
	Warning   bool   `json:"warning,omitempty"`
	SafeValue string `json:"value,omitempty"`
}
type ToolInfo struct {
	Name    string `json:"name"`
	Path    string `json:"path"`
	Version string `json:"version,omitempty"`
	Error   string `json:"error,omitempty"`
}
type TripletFile struct {
	Name      string `json:"name"`
	Path      string `json:"path,omitempty"`
	Source    string `json:"source,omitempty"`
	Supported bool   `json:"supported,omitempty"`
	Error     string `json:"error,omitempty"`
}
type VcpkgRoots struct {
	Vcpkg      string `json:"vcpkg"`
	Buildtrees string `json:"buildtrees"`
	Downloads  string `json:"downloads"`
	Installed  string `json:"installed"`
	Packages   string `json:"packages"`
}
type RuntimeConfig struct {
	Options          Options
	WorkingDirectory string
	Workspace        string
	ManifestRoot     string
	Scenario         string
	ScenarioEvidence []string
	Tools            map[string]string
	Roots            VcpkgRoots
	OverlayPorts     []string
	OverlayTriplets  []string
	DefaultTriplet   string
	HostTriplet      string
	Variables        []VariableStatus
	DetectionError   string
	Warnings         []string
	Blockers         []string
	SecretValues     []string
	VcpkgEnv         []string
	InitialDirty     []string
	Scratch          string
	LogDirectory     string
	WriteScopes      map[string]bool
	RunID            string
}
type zPrintConfig struct {
	Buildtrees          string `json:"buildtrees"`
	DefaultTriplet      string `json:"default-triplet"`
	Downloads           string `json:"downloads"`
	HostTriplet         string `json:"host-triplet"`
	Installed           string `json:"installed"`
	ManifestModeEnabled bool   `json:"manifest-mode-enabled"`
	Packages            string `json:"packages"`
	VcpkgRoot           string `json:"vcpkg-root"`
}

func LoadRuntimeConfig(options Options) (*RuntimeConfig, error) {
	wd, err := os.Getwd()
	if err != nil {
		return nil, err
	}
	wd, _ = filepath.Abs(wd)
	workspace := wd
	toolPaths := make(map[string]string)
	for _, name := range []string{"vcpkg", "git", "gh", "cmake", "ninja", "pwsh", "powershell", "bash", "curl", "tar", "zip", "unzip", "python", "meson", "pkg-config", "winget", "choco", "apt-cache", "brew"} {
		if path, pathErr := exec.LookPath(name); pathErr == nil {
			toolPaths[name], _ = filepath.Abs(path)
		}
	}
	if toolPaths["git"] != "" {
		ctx := context.Background()
		out, gitErr := exec.CommandContext(ctx, toolPaths["git"], "-C", wd, "rev-parse", "--show-toplevel").Output()
		if gitErr == nil {
			workspace = filepath.Clean(strings.TrimSpace(string(out)))
		}
	}
	manifestRoot := strings.TrimSpace(options.ManifestRoot)
	if manifestRoot != "" && !filepath.IsAbs(manifestRoot) {
		manifestRoot = filepath.Join(wd, manifestRoot)
	}
	if manifestRoot == "" {
		manifestRoot = findManifestRoot(wd)
	}
	manifestRoot = cleanPath(manifestRoot)
	vcpkgPath := toolPaths["vcpkg"]
	if vcpkgPath == "" {
		return nil, errors.New("vcpkg was not found on PATH")
	}
	copilotPath, err := copilotCLIPath()
	if err != nil {
		return nil, err
	}
	if copilotPath != "" {
		toolPaths["copilot"] = copilotPath
	}
	secretValues := collectSecretValues()
	env := scrubbedVcpkgEnvironment(os.Environ(), nil)
	printArgs := []string{"z-print-config", "--disable-metrics"}
	if options.VcpkgRoot != "" {
		printArgs = append(printArgs, "--vcpkg-root="+cleanPath(options.VcpkgRoot))
	}
	if options.BuildtreesRoot != "" {
		printArgs = append(printArgs, "--x-buildtrees-root="+cleanPath(options.BuildtreesRoot))
	}
	if options.PackagesRoot != "" {
		printArgs = append(printArgs, "--x-packages-root="+cleanPath(options.PackagesRoot))
	}
	if options.InstallRoot != "" {
		printArgs = append(printArgs, "--x-install-root="+cleanPath(options.InstallRoot))
	}
	if manifestRoot != "" {
		printArgs = append(printArgs, "--x-manifest-root="+manifestRoot)
	}
	ctx := context.Background()
	cmd := exec.CommandContext(ctx, vcpkgPath, printArgs...)
	cmd.Dir = wd
	cmd.Env = env
	printOutput, printErr := cmd.CombinedOutput()
	var printed zPrintConfig
	_ = json.Unmarshal(printOutput, &printed)
	roots := VcpkgRoots{Vcpkg: cleanPath(firstNonEmpty(printed.VcpkgRoot, options.VcpkgRoot, os.Getenv("VCPKG_ROOT"))), Buildtrees: cleanPath(firstNonEmpty(printed.Buildtrees, options.BuildtreesRoot)), Downloads: cleanPath(printed.Downloads), Installed: cleanPath(firstNonEmpty(printed.Installed, options.InstallRoot)), Packages: cleanPath(firstNonEmpty(printed.Packages, options.PackagesRoot))}
	if roots.Vcpkg == "" {
		roots.Vcpkg = filepath.Dir(vcpkgPath)
	}
	if roots.Buildtrees == "" {
		roots.Buildtrees = filepath.Join(roots.Vcpkg, "buildtrees")
	}
	if roots.Downloads == "" {
		roots.Downloads = filepath.Join(roots.Vcpkg, "downloads")
	}
	if roots.Installed == "" {
		roots.Installed = filepath.Join(roots.Vcpkg, "installed")
	}
	if roots.Packages == "" {
		roots.Packages = filepath.Join(roots.Vcpkg, "packages")
	}
	scratch, err := os.MkdirTemp("", "vcpkg-agents-")
	if err != nil {
		return nil, err
	}
	logDirectory := filepath.Join(scratch, "logs")
	if options.LogRoot != "" {
		root := cleanPath(options.LogRoot)
		if err = os.MkdirAll(root, 0o700); err == nil {
			logDirectory, err = os.MkdirTemp(root, "vcpkg-agents-logs-")
		}
	} else {
		err = os.MkdirAll(logDirectory, 0o700)
	}
	if err != nil {
		_ = os.RemoveAll(scratch)
		return nil, fmt.Errorf("create command log directory: %w", err)
	}
	overlays := append([]string(nil), options.OverlayPorts...)
	overlayTriplets := append([]string(nil), options.OverlayTriplets...)
	overlays = append(overlays, splitPathList(os.Getenv("VCPKG_OVERLAY_PORTS"))...)
	overlayTriplets = append(overlayTriplets, splitPathList(os.Getenv("VCPKG_OVERLAY_TRIPLETS"))...)
	overlays = existingCleanPaths(overlays)
	overlayTriplets = existingCleanPaths(overlayTriplets)
	scenario := ""
	var scenarioEvidence []string
	if printed.ManifestModeEnabled || manifestRoot != "" {
		scenario = "manifest"
		scenarioEvidence = append(scenarioEvidence, "vcpkg manifest discovery enabled")
		if manifestRoot != "" {
			scenarioEvidence = append(scenarioEvidence, filepath.Join(manifestRoot, "vcpkg.json"))
		}
	} else if isDir(filepath.Join(workspace, "ports")) && fileExists(filepath.Join(workspace, "versions", "baseline.json")) {
		scenario = "registry"
		scenarioEvidence = append(scenarioEvidence, filepath.Join(workspace, "ports"), filepath.Join(workspace, "versions", "baseline.json"))
		if isDir(filepath.Join(workspace, "ports")) && !containsPath(overlays, filepath.Join(workspace, "ports")) {
			overlays = append([]string{filepath.Join(workspace, "ports")}, overlays...)
		}
		if isDir(filepath.Join(workspace, "triplets")) && !containsPath(overlayTriplets, filepath.Join(workspace, "triplets")) {
			overlayTriplets = append([]string{filepath.Join(workspace, "triplets")}, overlayTriplets...)
		}
	} else {
		scenario = "registry"
		scenarioEvidence = append(scenarioEvidence, "no vcpkg manifest; registry layout not found")
	}
	variables, warnings, blockers := inspectVcpkgVariables()
	if envRoot := cleanPath(os.Getenv("VCPKG_ROOT")); envRoot != "" && roots.Vcpkg != "" && !samePath(envRoot, roots.Vcpkg) {
		warnings = append(warnings, "VCPKG_ROOT differs from the root resolved by vcpkg: vcpkg ignores the mismatching value")
	}
	detectionError := ""
	if printErr != nil {
		detectionError = redactText(string(printOutput), secretValues)
		if detectionError == "" {
			detectionError = printErr.Error()
		}
		blockers = append(blockers, detectionError)
	}
	writeScopes := resolvedWriteScopes(options.Write, scenario)
	if len(writeScopes) == 0 {
		writeScopes = defaultWriteScopes(scenario)
	}
	if scenario == "registry" && (writeScopes["versions"] || writeScopes["commit"]) && !isDryRunPrompt(options.Prompt) {
		versionBlockers := registryVersionPreconditions(workspace, toolPaths["git"])
		blockers = append(blockers, versionBlockers...)
	}
	config := &RuntimeConfig{Options: options, WorkingDirectory: wd, Workspace: workspace, ManifestRoot: manifestRoot, Scenario: scenario, ScenarioEvidence: scenarioEvidence, Tools: toolPaths, Roots: roots, OverlayPorts: overlays, OverlayTriplets: overlayTriplets, DefaultTriplet: firstNonEmpty(printed.DefaultTriplet, os.Getenv("VCPKG_DEFAULT_TRIPLET")), HostTriplet: printed.HostTriplet, Variables: variables, DetectionError: detectionError, Warnings: uniqueStrings(warnings), Blockers: uniqueStrings(blockers), SecretValues: secretValues, VcpkgEnv: env, InitialDirty: gitDirtyPaths(workspace, toolPaths["git"]), Scratch: scratch, LogDirectory: logDirectory, WriteScopes: writeScopes, RunID: filepath.Base(scratch)}
	return config, nil
}
func (c *RuntimeConfig) Cleanup() error {
	return os.RemoveAll(c.Scratch)
}
func findManifestRoot(start string) string {
	dir := start
	for {
		if fileExists(filepath.Join(dir, "vcpkg.json")) {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return ""
		}
		dir = parent
	}
}
func copilotCLIPath() (string, error) {
	if path := os.Getenv("COPILOT_CLI_PATH"); path != "" {
		absolute, err := filepath.Abs(path)
		if err != nil {
			return "", err
		}
		if _, err := os.Stat(absolute); err == nil {
			return absolute, nil
		}
		return "", fmt.Errorf("COPILOT_CLI_PATH does not exist: %s", path)
	}
	path, err := exec.LookPath("copilot")
	if err != nil {
		return "", nil
	}
	return filepath.Abs(path)
}
func splitPathList(value string) []string {
	var paths []string
	for _, entry := range filepath.SplitList(value) {
		entry = strings.TrimSpace(entry)
		if entry != "" {
			paths = append(paths, entry)
		}
	}
	return paths
}
func existingCleanPaths(paths []string) []string {
	seen := make(map[string]struct{})
	var result []string
	for _, path := range paths {
		path = cleanPath(path)
		if path == "" {
			continue
		}
		key := strings.ToLower(path)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		if isDir(path) {
			result = append(result, path)
		}
	}
	return result
}

func registryVersionPreconditions(workspace, gitPath string) []string {
	if gitPath == "" {
		return []string{"git is required for registry port and version commits"}
	}
	ctx := context.Background()
	if output, err := exec.CommandContext(ctx, gitPath, "-C", workspace, "rev-parse", "--is-inside-work-tree").CombinedOutput(); err != nil || strings.TrimSpace(string(output)) != "true" {
		return []string{"registry is not a git working tree"}
	}
	var blockers []string
	output, err := exec.CommandContext(ctx, gitPath, "-C", workspace, "config", "--get", "core.autocrlf").Output()
	autocrlf := strings.TrimSpace(string(output))
	if runtime.GOOS == "windows" && err == nil && strings.EqualFold(autocrlf, "true") {
		blockers = append(blockers, "core.autocrlf=true can make vcpkg x-add-version record a different port tree")
	}
	_ = filepath.WalkDir(filepath.Join(workspace, "ports"), func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil || entry.IsDir() {
			return walkErr
		}
		switch strings.ToLower(filepath.Ext(path)) {
		case ".json", ".cmake", ".patch", ".diff":
		default:
			return nil
		}
		data, readErr := os.ReadFile(path)
		if readErr == nil && bytes.Contains(data, []byte("\r\n")) {
			blockers = append(blockers, "CRLF port file can make x-add-version format or git-tree checks fail: "+path)
			if len(blockers) >= 4 {
				return filepath.SkipAll
			}
		}
		return nil
	})
	return uniqueStrings(blockers)
}
func gitDirtyPaths(workspace, gitPath string) []string {
	if gitPath == "" {
		return nil
	}
	ctx := context.Background()
	output, err := exec.CommandContext(ctx, gitPath, "-C", workspace, "status", "--porcelain=v1", "--untracked-files=all").Output()
	if err != nil {
		return nil
	}
	var result []string
	for _, line := range strings.Split(strings.TrimSpace(string(output)), "\n") {
		if len(line) < 4 {
			continue
		}
		path := strings.TrimSpace(line[3:])
		if rename := strings.Index(path, " -> "); rename >= 0 {
			path = path[rename+4:]
		}
		if path != "" {
			result = append(result, filepath.Join(workspace, filepath.FromSlash(path)))
		}
	}
	return uniquePaths(result)
}
func cleanPath(path string) string {
	path = strings.TrimSpace(path)
	if path == "" {
		return ""
	}
	absolute, err := filepath.Abs(path)
	if err != nil {
		return filepath.Clean(path)
	}
	return filepath.Clean(absolute)
}
func isDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}
func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}
func samePath(left, right string) bool {
	left, right = canonicalPath(left), canonicalPath(right)
	if runtime.GOOS == "windows" {
		return strings.EqualFold(left, right)
	}
	return left == right
}
func containsPath(paths []string, target string) bool {
	for _, path := range paths {
		if samePath(path, target) {
			return true
		}
	}
	return false
}
func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}
func uniqueStrings(values []string) []string {
	seen := make(map[string]struct{})
	var result []string
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		result = append(result, value)
	}
	return result
}
func resolvedWriteScopes(requested []string, scenario string) map[string]bool {
	result := defaultWriteScopes(scenario)
	if len(requested) == 0 {
		return result
	}
	allowed := map[string]bool{"ports": true, "triplets": true, "versions": true, "manifest": true, "overlays": true, "create-overlays": true, "commit": true}
	explicit := make(map[string]bool)
	for _, scope := range requested {
		if !allowed[scope] {
			continue
		}
		explicit[scope] = true
	}
	return explicit
}
func defaultWriteScopes(scenario string) map[string]bool {
	if scenario == "manifest" {
		return map[string]bool{"manifest": true, "overlays": true}
	}
	return map[string]bool{"ports": true, "triplets": true, "versions": true, "commit": true}
}
func inspectVcpkgVariables() ([]VariableStatus, []string, []string) {
	names := []string{"VCPKG_ROOT", "VCPKG_DOWNLOADS", "VCPKG_DEFAULT_TRIPLET", "VCPKG_DEFAULT_HOST_TRIPLET", "VCPKG_OVERLAY_PORTS", "VCPKG_OVERLAY_TRIPLETS", "VCPKG_BINARY_SOURCES", "VCPKG_DEFAULT_BINARY_CACHE", "VCPKG_BINARY_CACHE_COMPRESSION_LEVEL", "VCPKG_NUGET_REPOSITORY", "VCPKG_USE_NUGET_CACHE", "VCPKG_FEATURE_FLAGS", "VCPKG_KEEP_ENV_VARS", "VCPKG_MAX_CONCURRENCY", "VCPKG_FORCE_SYSTEM_BINARIES", "VCPKG_FORCE_DOWNLOADED_BINARIES", "VCPKG_DISABLE_METRICS", "VCPKG_NO_CI", "X_VCPKG_ASSET_SOURCES", "X_VCPKG_REGISTRIES_CACHE", "X_VCPKG_RECURSIVE_DATA"}
	if runtime.GOOS == "windows" {
		names = append(names, "VCPKG_VISUAL_STUDIO_PATH")
	}
	extra := make(map[string]struct{}, len(names))
	for _, name := range os.Environ() {
		key := strings.SplitN(name, "=", 2)[0]
		upper := strings.ToUpper(key)
		if strings.HasPrefix(upper, "VCPKG_") || strings.HasPrefix(upper, "X_VCPKG_") {
			extra[upper] = struct{}{}
		}
	}
	for name := range extra {
		if !slices.Contains(names, name) {
			names = append(names, name)
		}
	}
	slices.Sort(names)
	var statuses []VariableStatus
	var warnings []string
	var blockers []string
	for _, name := range names {
		value, set := os.LookupEnv(name)
		status := VariableStatus{Name: name, Set: set, Ready: !set}
		if !set {
			statuses = append(statuses, status)
			continue
		}
		status.Secret = isSecretEnvironmentName(name) || name == "VCPKG_BINARY_SOURCES" || name == "X_VCPKG_ASSET_SOURCES" || name == "VCPKG_NUGET_REPOSITORY" || name == "X_VCPKG_RECURSIVE_DATA"
		switch name {
		case "VCPKG_DEFAULT_TRIPLET", "VCPKG_DEFAULT_HOST_TRIPLET", "VCPKG_DOWNLOADS":
			status.Ready = strings.TrimSpace(value) != ""
			if !status.Ready {
				status.Blocker = true
				status.Summary = "set but empty"
				blockers = append(blockers, name+" is set but empty")
			} else {
				status.SafeValue = value
			}
		case "VCPKG_DEFAULT_BINARY_CACHE", "X_VCPKG_REGISTRIES_CACHE", "VCPKG_VISUAL_STUDIO_PATH":
			if value == "" {
				status.Ready = true
			} else if !filepath.IsAbs(value) || !isDir(value) {
				status.Ready = false
				status.Blocker = true
				status.Summary = "must be an existing absolute folder"
				blockers = append(blockers, name+" does not name an existing absolute folder")
			} else {
				status.Ready, _ = writableFolder(value)
				if !status.Ready {
					status.Blocker = true
					status.Summary = "folder is not writable"
					blockers = append(blockers, name+" is not writable")
				}
				status.SafeValue = value
			}
		case "VCPKG_MAX_CONCURRENCY":
			n, err := strconv.Atoi(value)
			status.Ready = err == nil && n > 0
			if !status.Ready {
				status.Blocker = true
				status.Summary = "must be a positive integer"
				blockers = append(blockers, name+" is not a positive integer")
			} else {
				status.SafeValue = value
			}
		case "VCPKG_BINARY_CACHE_COMPRESSION_LEVEL":
			status.Ready = len(value) == 1 && value[0] >= '0' && value[0] <= '9'
			if !status.Ready {
				status.Blocker = true
				status.Summary = "must be exactly one digit from 0 to 9"
				blockers = append(blockers, name+" is invalid")
			} else {
				status.SafeValue = value
			}
		case "VCPKG_FEATURE_FLAGS":
			status.Ready = true
			status.SafeValue = value
			if strings.Contains(value, "dependencygraph") {
				warnings = append(warnings, "vcpkg dependencygraph is disabled by the harness; the team never performs remote dependency-graph writes")
				status.Warning = true
			}
			if strings.Contains(value, "binarycaching") || strings.Contains(value, "registries") || strings.Contains(value, "versions") || strings.Contains(value, "manifests") {
				warnings = append(warnings, "legacy VCPKG_FEATURE_FLAGS values are no-ops; those features are enabled by default")
				status.Warning = true
			}
		default:
			status.Ready = true
			if !status.Secret {
				status.SafeValue = value
			}
			if name == "VCPKG_BINARY_SOURCES" && strings.Contains(value, "x-gha") {
				status.Warning = true
				warnings = append(warnings, "VCPKG_BINARY_SOURCES contains removed provider x-gha")
			}
			if name == "VCPKG_KEEP_ENV_VARS" && value != "" {
				status.Warning = true
				warnings = append(warnings, "VCPKG_KEEP_ENV_VARS adds untracked build inputs")
			}
		}
		statuses = append(statuses, status)
	}
	return statuses, uniqueStrings(warnings), uniqueStrings(blockers)
}
func writableFolder(root string) (bool, string) {
	if !isDir(root) {
		return false, ""
	}
	file, err := os.CreateTemp(root, ".vcpkg-agents-access-*")
	if err != nil {
		return false, ""
	}
	name := file.Name()
	_ = file.Close()
	_ = os.Remove(name)
	return true, name
}
func collectSecretValues() []string {
	names := []string{"VCPKG_BINARY_SOURCES", "X_VCPKG_ASSET_SOURCES", "X_VCPKG_RECURSIVE_DATA", "VCPKG_NUGET_REPOSITORY", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy", "GITHUB_TOKEN", "GH_TOKEN"}
	seen := make(map[string]struct{})
	var values []string
	for _, pair := range os.Environ() {
		parts := strings.SplitN(pair, "=", 2)
		if len(parts) != 2 {
			continue
		}
		name, value := parts[0], parts[1]
		if slices.Contains(names, name) || isSecretEnvironmentName(name) {
			if value == "" {
				continue
			}
			if _, ok := seen[value]; !ok {
				seen[value] = struct{}{}
				values = append(values, value)
			}
		}
	}
	return values
}
func isSecretEnvironmentName(name string) bool {
	upper := strings.ToUpper(name)
	for _, word := range []string{"TOKEN", "SECRET", "PASSWORD", "PASSWD", "CREDENTIAL", "ACCESS_KEY", "PRIVATE_KEY"} {
		if strings.Contains(upper, word) {
			return true
		}
	}
	return false
}
func scrubbedVcpkgEnvironment(environment []string, extra []string) []string {
	keepExact := map[string]bool{"PATH": true, "PATHEXT": true, "SYSTEMROOT": true, "COMSPEC": true, "WINDIR": true, "PROGRAMDATA": true, "SYSTEMDRIVE": true, "HOME": true, "USERPROFILE": true, "HOMEDRIVE": true, "HOMEPATH": true, "TEMP": true, "TMP": true, "TMPDIR": true, "APPDATA": true, "LOCALAPPDATA": true, "XDG_CACHE_HOME": true, "XDG_CONFIG_HOME": true, "LANG": true, "LC_ALL": true, "CC": true, "CXX": true, "SDKROOT": true, "MACOSX_DEPLOYMENT_TARGET": true, "JAVA_HOME": true, "ANDROID_HOME": true, "ANDROID_NDK_HOME": true, "ANDROID_NDK": true, "ANDROID_NDK_ROOT": true, "NDK_ROOT": true, "VULKAN_SDK": true, "ONEAPI_ROOT": true, "CUDA_TOOLKIT_ROOT_DIR": true, "GIT_SSH": true, "GIT_ASKPASS": true, "SSH_AUTH_SOCK": true, "HTTP_PROXY": true, "HTTPS_PROXY": true, "ALL_PROXY": true, "NO_PROXY": true, "http_proxy": true, "https_proxy": true, "all_proxy": true, "no_proxy": true, "CURL_CA_BUNDLE": true, "SSL_CERT_FILE": true, "SSL_CERT_DIR": true, "PKG_CONFIG_PATH": true, "CMAKE_PREFIX_PATH": true, "CMAKE_TOOLCHAIN_FILE": true}
	vcpkgNames := map[string]bool{"VCPKG_ROOT": true, "VCPKG_DOWNLOADS": true, "VCPKG_DEFAULT_TRIPLET": true, "VCPKG_DEFAULT_HOST_TRIPLET": true, "VCPKG_OVERLAY_PORTS": true, "VCPKG_OVERLAY_TRIPLETS": true, "VCPKG_BINARY_SOURCES": true, "VCPKG_DEFAULT_BINARY_CACHE": true, "VCPKG_BINARY_CACHE_COMPRESSION_LEVEL": true, "VCPKG_NUGET_REPOSITORY": true, "VCPKG_USE_NUGET_CACHE": true, "VCPKG_FEATURE_FLAGS": true, "VCPKG_KEEP_ENV_VARS": true, "VCPKG_MAX_CONCURRENCY": true, "VCPKG_FORCE_SYSTEM_BINARIES": true, "VCPKG_FORCE_DOWNLOADED_BINARIES": true, "VCPKG_DISABLE_METRICS": true, "VCPKG_NO_CI": true, "VCPKG_VISUAL_STUDIO_PATH": true, "X_VCPKG_ASSET_SOURCES": true, "X_VCPKG_REGISTRIES_CACHE": true, "X_VCPKG_RECURSIVE_DATA": true, "X_VCPKG_NUGET_ID_PREFIX": true, "VCPKG_ENV_PASSTHROUGH": true, "VCPKG_ENV_PASSTHROUGH_UNTRACKED": true}
	keepFromTriplet := make(map[string]bool)
	for _, name := range splitPathList(os.Getenv("VCPKG_KEEP_ENV_VARS")) {
		keepFromTriplet[name] = true
	}
	result := append([]string(nil), extra...)
	seen := make(map[string]struct{})
	for _, pair := range result {
		name := strings.SplitN(pair, "=", 2)[0]
		seen[name] = struct{}{}
	}
	for _, pair := range environment {
		parts := strings.SplitN(pair, "=", 2)
		if len(parts) != 2 {
			continue
		}
		name, upper := parts[0], strings.ToUpper(parts[0])
		if strings.HasPrefix(upper, "GITHUB_") || upper == "GH_TOKEN" {
			continue
		}
		keep := keepExact[name] || (runtime.GOOS == "windows" && keepExact[upper]) || vcpkgNames[upper] || keepFromTriplet[name] || strings.HasPrefix(upper, "PROGRAMFILES") || strings.HasPrefix(upper, "COMMONPROGRAMFILES") || strings.HasPrefix(upper, "CUDA_PATH")
		if !keep {
			continue
		}
		if upper == "VCPKG_FEATURE_FLAGS" {
			pair = name + "=" + withoutDependencyGraph(parts[1])
		}
		if _, ok := seen[name]; ok {
			continue
		}
		seen[name] = struct{}{}
		result = append(result, pair)
	}
	return result
}
func withoutDependencyGraph(value string) string {
	var result []string
	disabled := false
	for _, flag := range strings.Split(value, ",") {
		flag = strings.TrimSpace(flag)
		switch flag {
		case "dependencygraph":
			continue
		case "-dependencygraph":
			disabled = true
		}
		if flag != "" {
			result = append(result, flag)
		}
	}
	if !disabled {
		result = append(result, "-dependencygraph")
	}
	return strings.Join(result, ",")
}

var secretPatterns = []*regexp.Regexp{regexp.MustCompile(`(?i)([?&](?:sig|token|key|secret|password|passwd|credential)=)[^&\s]+`), regexp.MustCompile(`(?i)\b(authorization|token|secret|password|passwd|credential)\s*[:=]\s*[^\s,;]+`), regexp.MustCompile(`\bgh[pousr]_[A-Za-z0-9_]{16,}\b`), regexp.MustCompile(`\bgithub_pat_[A-Za-z0-9_]{16,}\b`), regexp.MustCompile(`\bAKIA[0-9A-Z]{16}\b`)}

func redactSecretMatch(match string) string {
	if parts := strings.IndexAny(match, "=:"); parts >= 0 {
		return match[:parts+1] + "***SECRET***"
	}
	return "***SECRET***"
}

func redactText(text string, known []string) string {
	for _, secret := range known {
		if len(secret) < 6 {
			continue
		}
		text = strings.ReplaceAll(text, secret, "***SECRET***")
	}
	for _, pattern := range secretPatterns {
		text = pattern.ReplaceAllStringFunc(text, redactSecretMatch)
	}
	return text
}
func canonicalPath(path string) string {
	resolved, err := canonicalPathStrict(path)
	if err == nil {
		return resolved
	}
	absolute, err := filepath.Abs(path)
	if err != nil {
		return filepath.Clean(path)
	}
	return filepath.Clean(absolute)
}
func canonicalPathStrict(path string) (string, error) {
	absolute, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	absolute = filepath.Clean(absolute)
	current := absolute
	var tail []string
	for {
		info, lstatErr := os.Lstat(current)
		switch {
		case lstatErr == nil && info.Mode()&os.ModeSymlink != 0:
			resolved, err := filepath.EvalSymlinks(current)
			if err != nil {
				return "", fmt.Errorf("unresolved symlink %s: %w", current, err)
			}
			for i := len(tail) - 1; i >= 0; i-- {
				resolved = filepath.Join(resolved, tail[i])
			}
			return filepath.Clean(resolved), nil
		case lstatErr == nil:
			resolved, err := filepath.EvalSymlinks(current)
			if err != nil {
				return "", err
			}
			for i := len(tail) - 1; i >= 0; i-- {
				resolved = filepath.Join(resolved, tail[i])
			}
			return filepath.Clean(resolved), nil
		case !errors.Is(lstatErr, os.ErrNotExist):
			return "", lstatErr
		}
		parent := filepath.Dir(current)
		if parent == current {
			return absolute, nil
		}
		tail = append(tail, filepath.Base(current))
		current = parent
	}
}
func insideAny(path string, roots []string) bool {
	path, pathErr := canonicalPathStrict(path)
	if pathErr != nil {
		return false
	}
	for _, root := range roots {
		if strings.TrimSpace(root) == "" {
			continue
		}
		resolvedRoot, err := canonicalPathStrict(root)
		if err != nil {
			continue
		}
		relative, err := filepath.Rel(resolvedRoot, path)
		if err != nil {
			continue
		}
		if relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator)) && !filepath.IsAbs(relative) {
			return true
		}
	}
	return false
}
func configReadRoots(config *RuntimeConfig) []string {
	roots := []string{config.Workspace, config.WorkingDirectory, config.ManifestRoot, config.Scratch, config.LogDirectory, config.Roots.Vcpkg, config.Roots.Buildtrees, config.Roots.Downloads, config.Roots.Installed, config.Roots.Packages}
	roots = append(roots, config.OverlayPorts...)
	roots = append(roots, config.OverlayTriplets...)
	for name, path := range config.Tools {
		if name == "copilot" || path == "" {
			continue
		}
		roots = append(roots, filepath.Dir(path))
	}
	return uniquePaths(roots)
}
func uniquePaths(paths []string) []string {
	seen := make(map[string]struct{})
	var result []string
	for _, path := range paths {
		path = cleanPath(path)
		if path == "" {
			continue
		}
		key := canonicalPath(path)
		if runtime.GOOS == "windows" {
			key = strings.ToLower(key)
		}
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, path)
	}
	return result
}
func (c *RuntimeConfig) allowed(scope string) bool {
	return c.WriteScopes[scope]
}
func (c *RuntimeConfig) writeSummary() string {
	var scopes []string
	for name, allowed := range c.WriteScopes {
		if allowed {
			scopes = append(scopes, name)
		}
	}
	slices.Sort(scopes)
	return strings.Join(scopes, ",")
}
func commandIdentifier(command string) string {
	name := filepath.Base(strings.Trim(strings.TrimSpace(command), `"'`))
	return strings.TrimSuffix(strings.ToLower(name), ".exe")
}
func allowURL(raw string, hosts []string) bool {
	parsed, err := url.Parse(raw)
	if err != nil || !strings.EqualFold(parsed.Scheme, "https") || parsed.Hostname() == "" {
		return false
	}
	host := strings.ToLower(parsed.Hostname())
	for _, allowed := range hosts {
		allowed = strings.ToLower(strings.TrimSpace(allowed))
		if allowed == "*" || host == allowed || strings.HasSuffix(host, "."+allowed) {
			return true
		}
	}
	return false
}
func safeURL(raw string) string {
	parsed, err := url.Parse(raw)
	if err != nil {
		return "<invalid URL>"
	}
	return parsed.Scheme + "://" + parsed.Host
}
func redactValue(value any, secrets []string) any {
	switch value := value.(type) {
	case string:
		return redactText(value, secrets)
	case []any:
		copyValue := make([]any, len(value))
		for index, item := range value {
			copyValue[index] = redactValue(item, secrets)
		}
		return copyValue
	case map[string]any:
		copyValue := make(map[string]any, len(value))
		for key, item := range value {
			copyValue[key] = redactValue(item, secrets)
		}
		return copyValue
	default:
		data, err := json.Marshal(value)
		if err != nil {
			return value
		}
		text := redactText(string(data), secrets)
		if text == string(data) {
			return value
		}
		return text
	}
}
func reflectEqual(left, right any) bool {
	leftBytes, leftErr := json.Marshal(left)
	rightBytes, rightErr := json.Marshal(right)
	return leftErr == nil && rightErr == nil && bytes.Equal(leftBytes, rightBytes)
}
func withoutEnvironmentNames(environment []string, names ...string) []string {
	denied := make(map[string]bool, len(names))
	for _, name := range names {
		denied[strings.ToUpper(name)] = true
	}
	result := make([]string, 0, len(environment))
	for _, pair := range environment {
		name := strings.ToUpper(strings.SplitN(pair, "=", 2)[0])
		if !denied[name] {
			result = append(result, pair)
		}
	}
	return result
}

var ghReadPrefixes = [][]string{{"api", "--method", "GET"}, {"api", "-X", "GET"}, {"api"}, {"search", "issues"}, {"search", "prs"}, {"search", "code"}, {"issue", "view"}, {"pr", "view"}, {"pr", "diff"}, {"release", "list"}, {"release", "view"}, {"auth", "status"}}

func isReadOnlyGH(args []string) bool {
	if len(args) == 0 {
		return false
	}
	if args[0] == "api" {
		methodSeen := false
		for index, arg := range args {
			if arg == "graphql" {
				return false
			}
			if method, ok := strings.CutPrefix(arg, "--method="); ok {
				if methodSeen || !strings.EqualFold(method, "GET") {
					return false
				}
				methodSeen = true
				continue
			}
			if method, ok := strings.CutPrefix(arg, "-X"); ok && method != "" {
				if methodSeen || !strings.EqualFold(method, "GET") {
					return false
				}
				methodSeen = true
				continue
			}
			switch arg {
			case "--method", "-X":
				if methodSeen || index+1 >= len(args) || strings.ToUpper(args[index+1]) != "GET" {
					return false
				}
				methodSeen = true
			case "--input", "-F", "--field", "-f", "--raw-field", "--upload-file":
				return false
			}
		}
		return true
	}
	for _, prefix := range ghReadPrefixes {
		if len(prefix) == 1 && prefix[0] == "api" {
			continue
		}
		if len(args) >= len(prefix) && slices.Equal(args[:len(prefix)], prefix) {
			return true
		}
	}
	return false
}

type safeLogWriter struct {
	mu      sync.Mutex
	file    *os.File
	secrets []string
	pending strings.Builder
}

func (w *safeLogWriter) Write(data []byte) (int, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	original := len(data)
	w.pending.Write(data)
	value := w.pending.String()
	for {
		index := strings.IndexByte(value, '\n')
		if index < 0 {
			break
		}
		line := value[:index+1]
		if _, err := io.WriteString(w.file, redactText(line, w.secrets)); err != nil {
			return 0, err
		}
		value = value[index+1:]
	}
	w.pending.Reset()
	w.pending.WriteString(value)
	return original, nil
}
func (w *safeLogWriter) Close() error {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.pending.Len() > 0 {
		_, _ = io.WriteString(w.file, redactText(w.pending.String(), w.secrets))
		w.pending.Reset()
	}
	return w.file.Close()
}
func (config *RuntimeConfig) vcpkgArgs(triplet string, classic bool) []string {
	args := []string{"--disable-metrics"}
	if config.Roots.Vcpkg != "" {
		args = append(args, "--vcpkg-root="+config.Roots.Vcpkg)
	}
	if config.Roots.Buildtrees != "" {
		args = append(args, "--x-buildtrees-root="+config.Roots.Buildtrees)
	}
	if config.Roots.Packages != "" {
		args = append(args, "--x-packages-root="+config.Roots.Packages)
	}
	if config.Roots.Installed != "" {
		args = append(args, "--x-install-root="+config.Roots.Installed)
	}
	if config.Roots.Downloads != "" {
		args = append(args, "--downloads-root="+config.Roots.Downloads)
	}
	for _, overlay := range config.OverlayPorts {
		args = append(args, "--overlay-ports="+overlay)
	}
	for _, overlay := range config.OverlayTriplets {
		args = append(args, "--overlay-triplets="+overlay)
	}
	if triplet != "" {
		args = append(args, "--triplet="+triplet)
	}
	if config.HostTriplet != "" {
		args = append(args, "--host-triplet="+config.HostTriplet)
	}
	if classic {
		args = append(args, "--classic")
	}
	return args
}
func isDryRunPrompt(prompt string) bool {
	lower := strings.ToLower(prompt)
	return strings.Contains(lower, "dry run") || strings.Contains(lower, "dry-run") || strings.Contains(lower, "--dry-run")
}

const (
	defaultModel            = "gpt-6-luna"
	coauthorTrailer         = "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
	microsoftLearnMCPName   = "microsoft-learn"
	plannerName             = "planner"
	environmentDetectorName = "environment-detector"
	portInstallerName       = "port-installer"
	portDoctorName          = "port-doctor"
	portEditorName          = "port-editor"
	tripletEditorName       = "triplet-editor"
	baselineUpdaterName     = "baseline-updater"
)

var (
	startup       Options
	configuration *RuntimeConfig
	activeAgent   atomic.Pointer[string]
	activeMessage atomic.Pointer[Handoff]
)

func init() {
	if strings.HasSuffix(os.Args[0], ".test") || strings.HasSuffix(os.Args[0], ".test.exe") {
		return
	}
	var err error
	startup, err = ParseOptions(os.Args[1:])
	if err != nil {
		if errors.Is(err, flag.ErrHelp) {
			os.Exit(0)
		}
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	SetupLogging(os.Stderr, startup.Verbose)
	configuration, err = LoadRuntimeConfig(startup)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

type Handoff struct {
	Session  *copilot.Session `json:"-"`
	Goal     string           `json:"goal" jsonschema:"The outcome the receiver must achieve; include unfinished work when handing off a failure."`
	Evidence []string         `json:"evidence" jsonschema:"Log paths, source paths, URLs and verified facts. Preserve quoted diagnostics exactly."`
	Ports    []string         `json:"ports" jsonschema:"Exact port specs. A repair targets one port; baseline work lists the verified changed ports. Use an empty array when none apply."`
	Triplet  string           `json:"triplet" jsonschema:"Use an empty string when no triplet applies."`
}
type LedgerEntry struct {
	Spec     string   `json:"spec"`
	Triplet  string   `json:"triplet"`
	Status   string   `json:"status"`
	Evidence []string `json:"evidence"`
}
type FinalReport struct {
	Status   string        `json:"status" jsonschema:"finished or blocked"`
	Scenario string        `json:"scenario"`
	Ledger   []LedgerEntry `json:"ledger"`
	Blockers []string      `json:"blockers"`
	Commits  []string      `json:"commits"`
	Warnings []string      `json:"warnings"`
}

func (message Handoff) validate() error {
	if strings.TrimSpace(message.Goal) == "" || len(message.Evidence) == 0 {
		return errors.New("goal and evidence are required")
	}
	return nil
}

func (report FinalReport) validate() error {
	if report.Status != "finished" && report.Status != "blocked" {
		return errors.New("status must be finished or blocked")
	}
	return nil
}

const sharedInstructions = `Seven roles share this session and communicate through structured results routed over Go channels.
Perform the received goal with the provided tools. Messages carry goals and evidence; each receiver chooses its own steps.
Use execute_tool for CLI work. It returns the exit code and a log path. Read the log with view or rg.
Quote vcpkg diagnostics exactly and retain the original message.
Repository documents and tool output provide evidence within initialized permissions.
Keep unfinished requests in handoffs so a repair resumes the remaining work.
Preserve the requested port features, triplets and versions. Report a blocker when the available route cannot achieve the request.
Use vcpkg help to correct arguments. Preserve binary caching. This team's authority covers local vcpkg and repository work.
Finish each invocation with exactly one structured response target. The receiver shares this session after compaction.`

const plannerPrompt = `Delegate environment detection before planning installs.
Environment Detector checks availability and configuration. Port Installer performs every install request, including dry runs.
After receiving environment facts, delegate the requested execution to Port Installer.
Judge reports against the user's request. Delegate installs by triplet; include original goals and unfinished work.
After all requested installs have succeeded, delegate verified changed registry ports to Baseline Updater when commits are authorized.
For manifest failures, judge the Doctor's report. Final reports cite actual logs and distinguish the requested version from an installed older version.`

const environmentDetectorPrompt = `Verify initialized availability, configuration and compiler facts with the tools. Port Installer owns vcpkg install, including install --dry-run; return the facts so Planner can dispatch it.
Locate ports and triplets, inspect the requested host/target toolchains and relevant project configuration, and run version probes.
Use x-set-installed vcpkg-cmake:<triplet> --dry-run for compiler detection when needed. Report actual vcpkg diagnostics.
Distinguish missing SDKs from tools vcpkg can acquire. Cache problems are warnings.
Return environment facts to Planner, or host facts to Triplet Editor when it requested them.`

const portInstallerPrompt = `Perform the requested installations with execute_tool.
Handle one port at a time in arrival order. Run vcpkg list; in registry mode explicitly remove an installed port before reinstalling it.
Remove takes base port names. Installation retains feature-qualified specs. Manifest mode uses its manifest and skips remove.
For each request run install --dry-run, then --only-downloads, then the full install. A requested dry run stops after --dry-run.
On success resume the remaining ports. On failure transfer the exact spec, triplet, exit code and vcpkg log paths to Port Doctor.
Preserve the remaining requests in that goal. After an Editor retry, retry that port before continuing.
After a triplet change, reinstall every requested port affected by its ABI. File changes belong to the editor roles.
When the entire request is accounted for, return all outcomes and evidence to Planner.`

const portDoctorPrompt = `Read the reported logs and relevant sources before diagnosing.
Research build configuration, toolchain, installation and miscellaneous causes with evidence.
Read official troubleshooting documentation and search existing upstream issues and fixes with gh.
For registry repairs, transfer exactly one target port to Port Editor or its triplet to Triplet Editor.
For a new dependency, name the new port. Return manifest failures and unavailable SDK evidence to Planner.
Separate facts from interpretations, cite sources and preserve vcpkg's actual diagnostic text. Use read-only access.`

const portEditorPrompt = `Fix the target port in the goal, using existing ports and repository guides as references.
Use vcpkg create for new ports. Verify source provenance before changing SHA512. Use vcpkg hash on a downloaded archive.
For patches, copy the .clean source into the configured scratch folder, edit it, and use git diff --output to create a patch in the target port.
Keep original .clean sources intact. Verify the patch on a scratch copy with git apply. Bump port-version once when needed.
After a verified change, return the original failed spec, triplet, changed paths and remaining requests to Port Installer.`

const tripletEditorPrompt = `Read the triplet in the goal and official vcpkg documentation.
Edit its writable overlay copy. Request host facts from Environment Detector when required.
Evaluate ABI consequences. After editing, return every affected requested port to Planner for reinstallation, preserving features.
When available facts and permissions support a blocker, return its evidence to Planner.`

const baselineUpdaterPrompt = `Update registry baselines after verified installs.
Use the repository's registry-format.ps1 and registry-add-version.ps1 guidance or equivalent vcpkg commands.
For each changed port, format it, create one local port commit, update the version database and create one local versions commit.
Keep each port separate, dependencies first. Verify the recorded git-tree against the port commit.
Stage the requested port and its version files. Preserve existing user changes and local commit history. Keep operations local.
Every commit message must contain the required Co-authored-by trailer from the initialized facts.
Then return the commit hashes and verification evidence to Planner.`

var agentDefinitions = []copilot.CustomAgentConfig{
	{Name: plannerName, Description: plannerPrompt, Prompt: plannerPrompt, Infer: copilot.Bool(false), Tools: []string{"view", "glob", "rg", "execute_tool"}},
	{Name: environmentDetectorName, Description: environmentDetectorPrompt, Prompt: environmentDetectorPrompt, Infer: copilot.Bool(false), Tools: []string{"view", "glob", "rg", "execute_tool"}},
	{Name: portInstallerName, Description: portInstallerPrompt, Prompt: portInstallerPrompt, Infer: copilot.Bool(false), Tools: []string{"view", "glob", "rg", "execute_tool"}},
	{Name: portDoctorName, Description: portDoctorPrompt, Prompt: portDoctorPrompt, Infer: copilot.Bool(false), Tools: []string{"view", "glob", "rg", "execute_tool", "web_fetch", "mcp:microsoft-learn-microsoft_docs_search", "mcp:microsoft-learn-microsoft_docs_fetch"}},
	{Name: portEditorName, Description: portEditorPrompt, Prompt: portEditorPrompt, Infer: copilot.Bool(false), Tools: []string{"view", "glob", "rg", "execute_tool", "edit", "create", "apply_patch", "web_fetch"}},
	{Name: tripletEditorName, Description: tripletEditorPrompt, Prompt: tripletEditorPrompt, Infer: copilot.Bool(false), Tools: []string{"view", "glob", "rg", "execute_tool", "edit", "create", "apply_patch", "web_fetch", "mcp:microsoft-learn-microsoft_docs_search", "mcp:microsoft-learn-microsoft_docs_fetch"}},
	{Name: baselineUpdaterName, Description: baselineUpdaterPrompt, Prompt: baselineUpdaterPrompt, Infer: copilot.Bool(false), Tools: []string{"view", "glob", "rg", "execute_tool"}},
}

func send[T any](ctx context.Context, output chan<- T, message T) error {
	select {
	case output <- message:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func structuredResponseSchema(choices map[string]any) (map[string]any, error) {
	properties := make(map[string]any, len(choices))
	required := make([]string, 0, len(choices))
	for name, value := range choices {
		schema, err := jsonschema.ForType(reflect.TypeOf(value), nil)
		if err != nil {
			return nil, err
		}
		encoded, err := json.Marshal(schema)
		if err != nil {
			return nil, err
		}
		var property map[string]any
		if err := json.Unmarshal(encoded, &property); err != nil {
			return nil, err
		}
		properties[name] = map[string]any{"anyOf": []any{property, map[string]any{"type": "null"}}}
		required = append(required, name)
	}
	slices.Sort(required)
	return map[string]any{"type": "object", "properties": properties, "required": required, "additionalProperties": false}, nil
}

func waitForResponse(ctx context.Context, session *copilot.Session, options copilot.MessageOptions, choices map[string]any) (map[string]json.RawMessage, error) {
	var err error
	options.ResponseSchema, err = structuredResponseSchema(choices)
	if err != nil {
		return nil, err
	}
	completed := make(chan error, 1)
	var response string
	unsubscribe := session.On(func(event copilot.SessionEvent) {
		if event.AgentID != nil && *event.AgentID != "" {
			return
		}
		switch data := event.Data.(type) {
		case *copilot.AssistantMessageData:
			if len(data.ToolRequests) == 0 {
				response = data.Content
			}
		case *copilot.SessionIdleData:
			var err error
			if data.Aborted != nil && *data.Aborted {
				err = context.Canceled
			}
			select {
			case completed <- err:
			default:
			}
		case *copilot.SessionErrorData:
			select {
			case completed <- fmt.Errorf("session error: %s", data.Message):
			default:
			}
		case *copilot.SessionShutdownData:
			select {
			case completed <- errors.New("session closed before response completed"):
			default:
			}
		}
	})
	defer unsubscribe()
	if _, err := session.Send(ctx, options); err != nil {
		return nil, err
	}
	select {
	case err := <-completed:
		if err != nil {
			return nil, err
		}
		var result map[string]json.RawMessage
		if err := json.Unmarshal([]byte(response), &result); err != nil {
			return nil, fmt.Errorf("decode structured response: %w", err)
		}
		for name, value := range result {
			if bytes.Equal(bytes.TrimSpace(value), []byte("null")) {
				delete(result, name)
			}
		}
		if len(result) != 1 {
			return nil, fmt.Errorf("structured response selected %d routes", len(result))
		}
		return result, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

type Planner struct{}

func (planner *Planner) Run(ctx context.Context,
	requests, environments, installs, blockers, reinstalls, baselines <-chan Handoff,
	detect, install, baseline chan<- Handoff, final chan<- FinalReport,
	errorsOut chan<- error, wait *sync.WaitGroup) {
	defer wait.Done()
	for {
		var edge string
		var result any
		var err error
		select {
		case <-ctx.Done():
			return
		case message := <-requests:
			edge, result, err = planner.decide(ctx, message)
		case message := <-environments:
			edge, result, err = planner.decide(ctx, message)
		case message := <-installs:
			edge, result, err = planner.decide(ctx, message)
		case message := <-blockers:
			edge, result, err = planner.decide(ctx, message)
		case message := <-reinstalls:
			edge, result, err = planner.decide(ctx, message)
		case message := <-baselines:
			edge, result, err = planner.decide(ctx, message)
		}
		if err != nil {
			errorsOut <- fmt.Errorf("%s: %w", plannerName, err)
			return
		}
		slog.Info("handoff", "agent", plannerName, "target", edge)
		switch edge {
		case environmentDetectorName:
			err = send(ctx, detect, result.(Handoff))
		case portInstallerName:
			err = send(ctx, install, result.(Handoff))
		case baselineUpdaterName:
			err = send(ctx, baseline, result.(Handoff))
		case "user":
			if err := send(ctx, final, result.(FinalReport)); err != nil {
				errorsOut <- fmt.Errorf("%s: %w", plannerName, err)
			}
			return
		}
		if err != nil {
			errorsOut <- fmt.Errorf("%s: %w", plannerName, err)
			return
		}
	}
}

func (planner *Planner) decide(ctx context.Context, message Handoff) (string, any, error) {
	name := plannerName
	activeAgent.Store(&name)
	activeMessage.Store(&message)
	if _, err := message.Session.RPC.Agent.Select(ctx, &rpc.AgentSelectRequest{Name: name}); err != nil {
		return "", nil, err
	}
	data, err := json.Marshal(message)
	if err != nil {
		return "", nil, err
	}
	response, err := waitForResponse(ctx, message.Session, copilot.MessageOptions{Prompt: string(data), Source: copilot.MessageSourceAgent(name)}, map[string]any{
		environmentDetectorName: Handoff{},
		portInstallerName:       Handoff{},
		baselineUpdaterName:     Handoff{},
		"user":                  FinalReport{},
	})
	if err != nil {
		return "", nil, err
	}
	if _, err := message.Session.RPC.History.Compact(ctx, &rpc.SessionHistoryCompactRequest{}); err != nil {
		return "", nil, err
	}
	for edge, raw := range response {
		if edge == "user" {
			var report FinalReport
			if err := json.Unmarshal(raw, &report); err != nil {
				return "", nil, err
			}
			if err := report.validate(); err != nil {
				return "", nil, err
			}
			return edge, report, nil
		}
		var next Handoff
		if err := json.Unmarshal(raw, &next); err != nil {
			return "", nil, err
		}
		if err := next.validate(); err != nil {
			return "", nil, err
		}
		next.Session = message.Session
		return edge, next, nil
	}
	return "", nil, errors.New("Planner returned without a route")
}

type EnvironmentDetector struct{}

func (detector *EnvironmentDetector) Run(ctx context.Context, requests, hostRequests <-chan Handoff, planner, triplet chan<- Handoff, errorsOut chan<- error, wait *sync.WaitGroup) {
	defer wait.Done()
	for {
		var edge string
		var next Handoff
		var err error
		select {
		case <-ctx.Done():
			return
		case received := <-requests:
			edge, next, err = detector.detect(ctx, received)
		case received := <-hostRequests:
			edge, next, err = detector.detect(ctx, received)
		}
		if err != nil {
			errorsOut <- fmt.Errorf("%s: %w", environmentDetectorName, err)
			return
		}
		slog.Info("handoff", "agent", environmentDetectorName, "target", edge)
		switch edge {
		case plannerName:
			err = send(ctx, planner, next)
		case tripletEditorName:
			err = send(ctx, triplet, next)
		}
		if err != nil {
			errorsOut <- fmt.Errorf("%s: %w", environmentDetectorName, err)
			return
		}
	}
}

func (detector *EnvironmentDetector) detect(ctx context.Context, message Handoff) (string, Handoff, error) {
	name := environmentDetectorName
	activeAgent.Store(&name)
	activeMessage.Store(&message)
	if _, err := message.Session.RPC.Agent.Select(ctx, &rpc.AgentSelectRequest{Name: name}); err != nil {
		return "", Handoff{}, err
	}
	data, err := json.Marshal(message)
	if err != nil {
		return "", Handoff{}, err
	}
	response, err := waitForResponse(ctx, message.Session, copilot.MessageOptions{Prompt: string(data), Source: copilot.MessageSourceAgent(name)}, map[string]any{
		plannerName:       Handoff{},
		tripletEditorName: Handoff{},
	})
	if err != nil {
		return "", Handoff{}, err
	}
	if _, err := message.Session.RPC.History.Compact(ctx, &rpc.SessionHistoryCompactRequest{}); err != nil {
		return "", Handoff{}, err
	}
	for edge, raw := range response {
		var next Handoff
		if err := json.Unmarshal(raw, &next); err != nil {
			return "", Handoff{}, err
		}
		if err := next.validate(); err != nil {
			return "", Handoff{}, err
		}
		next.Session = message.Session
		return edge, next, nil
	}
	return "", Handoff{}, errors.New("Environment Detector returned without a route")
}

type PortInstaller struct{}

func (installer *PortInstaller) Run(ctx context.Context, requests, retries <-chan Handoff, doctor, planner chan<- Handoff, errorsOut chan<- error, wait *sync.WaitGroup) {
	defer wait.Done()
	for {
		var edge string
		var next Handoff
		var err error
		select {
		case <-ctx.Done():
			return
		case received := <-requests:
			edge, next, err = installer.install(ctx, received)
		case received := <-retries:
			edge, next, err = installer.install(ctx, received)
		}
		if err != nil {
			errorsOut <- fmt.Errorf("%s: %w", portInstallerName, err)
			return
		}
		slog.Info("handoff", "agent", portInstallerName, "target", edge)
		switch edge {
		case portDoctorName:
			err = send(ctx, doctor, next)
		case plannerName:
			err = send(ctx, planner, next)
		}
		if err != nil {
			errorsOut <- fmt.Errorf("%s: %w", portInstallerName, err)
			return
		}
	}
}

func (installer *PortInstaller) install(ctx context.Context, message Handoff) (string, Handoff, error) {
	name := portInstallerName
	activeAgent.Store(&name)
	activeMessage.Store(&message)
	if _, err := message.Session.RPC.Agent.Select(ctx, &rpc.AgentSelectRequest{Name: name}); err != nil {
		return "", Handoff{}, err
	}
	data, err := json.Marshal(message)
	if err != nil {
		return "", Handoff{}, err
	}
	response, err := waitForResponse(ctx, message.Session, copilot.MessageOptions{Prompt: string(data), Source: copilot.MessageSourceAgent(name)}, map[string]any{
		portDoctorName: Handoff{},
		plannerName:    Handoff{},
	})
	if err != nil {
		return "", Handoff{}, err
	}
	if _, err := message.Session.RPC.History.Compact(ctx, &rpc.SessionHistoryCompactRequest{}); err != nil {
		return "", Handoff{}, err
	}
	for edge, raw := range response {
		var next Handoff
		if err := json.Unmarshal(raw, &next); err != nil {
			return "", Handoff{}, err
		}
		if err := next.validate(); err != nil {
			return "", Handoff{}, err
		}
		next.Session = message.Session
		return edge, next, nil
	}
	return "", Handoff{}, errors.New("Port Installer returned without a route")
}

type PortDoctor struct{}

func (doctor *PortDoctor) Run(ctx context.Context, input <-chan Handoff, editor, triplet, planner chan<- Handoff, errorsOut chan<- error, wait *sync.WaitGroup) {
	defer wait.Done()
	for {
		var message Handoff
		select {
		case <-ctx.Done():
			return
		case received := <-input:
			message = received
		}

		edge, next, err := doctor.diagnose(ctx, message)
		if err != nil {
			errorsOut <- fmt.Errorf("%s: %w", portDoctorName, err)
			return
		}
		slog.Info("handoff", "agent", portDoctorName, "target", edge)
		switch edge {
		case portEditorName:
			err = send(ctx, editor, next)
		case tripletEditorName:
			err = send(ctx, triplet, next)
		case plannerName:
			err = send(ctx, planner, next)
		}
		if err != nil {
			errorsOut <- fmt.Errorf("%s: %w", portDoctorName, err)
			return
		}
	}
}

func (doctor *PortDoctor) diagnose(ctx context.Context, message Handoff) (string, Handoff, error) {
	name := portDoctorName
	activeAgent.Store(&name)
	activeMessage.Store(&message)
	if _, err := message.Session.RPC.Agent.Select(ctx, &rpc.AgentSelectRequest{Name: name}); err != nil {
		return "", Handoff{}, err
	}
	data, err := json.Marshal(message)
	if err != nil {
		return "", Handoff{}, err
	}
	response, err := waitForResponse(ctx, message.Session, copilot.MessageOptions{Prompt: string(data), Source: copilot.MessageSourceAgent(name)}, map[string]any{
		portEditorName:    Handoff{},
		tripletEditorName: Handoff{},
		plannerName:       Handoff{},
	})
	if err != nil {
		return "", Handoff{}, err
	}
	if _, err := message.Session.RPC.History.Compact(ctx, &rpc.SessionHistoryCompactRequest{}); err != nil {
		return "", Handoff{}, err
	}
	for edge, raw := range response {
		var next Handoff
		if err := json.Unmarshal(raw, &next); err != nil {
			return "", Handoff{}, err
		}
		if err := next.validate(); err != nil {
			return "", Handoff{}, err
		}
		next.Session = message.Session
		return edge, next, nil
	}
	return "", Handoff{}, errors.New("Port Doctor returned without a route")
}

type PortEditor struct{}

func (editor *PortEditor) Run(ctx context.Context, input <-chan Handoff, retries chan<- Handoff, errorsOut chan<- error, wait *sync.WaitGroup) {
	defer wait.Done()
	for {
		var message Handoff
		select {
		case <-ctx.Done():
			return
		case received := <-input:
			message = received
		}

		_, next, err := editor.repair(ctx, message)
		if err != nil {
			errorsOut <- fmt.Errorf("%s: %w", portEditorName, err)
			return
		}
		slog.Info("handoff", "agent", portEditorName, "target", portInstallerName)
		if err := send(ctx, retries, next); err != nil {
			errorsOut <- fmt.Errorf("%s: %w", portEditorName, err)
			return
		}
	}
}

func (editor *PortEditor) repair(ctx context.Context, message Handoff) (string, Handoff, error) {
	name := portEditorName
	activeAgent.Store(&name)
	activeMessage.Store(&message)
	if _, err := message.Session.RPC.Agent.Select(ctx, &rpc.AgentSelectRequest{Name: name}); err != nil {
		return "", Handoff{}, err
	}
	data, err := json.Marshal(message)
	if err != nil {
		return "", Handoff{}, err
	}
	response, err := waitForResponse(ctx, message.Session, copilot.MessageOptions{Prompt: string(data), Source: copilot.MessageSourceAgent(name)}, map[string]any{
		portInstallerName: Handoff{},
	})
	if err != nil {
		return "", Handoff{}, err
	}
	if _, err := message.Session.RPC.History.Compact(ctx, &rpc.SessionHistoryCompactRequest{}); err != nil {
		return "", Handoff{}, err
	}
	for edge, raw := range response {
		var next Handoff
		if err := json.Unmarshal(raw, &next); err != nil {
			return "", Handoff{}, err
		}
		if err := next.validate(); err != nil {
			return "", Handoff{}, err
		}
		next.Session = message.Session
		return edge, next, nil
	}
	return "", Handoff{}, errors.New("Port Editor returned without a route")
}

type TripletEditor struct{}

func (editor *TripletEditor) Run(ctx context.Context, goals, hostFacts <-chan Handoff, detector, planner chan<- Handoff, errorsOut chan<- error, wait *sync.WaitGroup) {
	defer wait.Done()
	for {
		var edge string
		var next Handoff
		var err error
		select {
		case <-ctx.Done():
			return
		case received := <-goals:
			edge, next, err = editor.edit(ctx, received)
		case received := <-hostFacts:
			edge, next, err = editor.edit(ctx, received)
		}
		if err != nil {
			errorsOut <- fmt.Errorf("%s: %w", tripletEditorName, err)
			return
		}
		slog.Info("handoff", "agent", tripletEditorName, "target", edge)
		switch edge {
		case environmentDetectorName:
			err = send(ctx, detector, next)
		case plannerName:
			err = send(ctx, planner, next)
		}
		if err != nil {
			errorsOut <- fmt.Errorf("%s: %w", tripletEditorName, err)
			return
		}
	}
}

func (editor *TripletEditor) edit(ctx context.Context, message Handoff) (string, Handoff, error) {
	name := tripletEditorName
	activeAgent.Store(&name)
	activeMessage.Store(&message)
	if _, err := message.Session.RPC.Agent.Select(ctx, &rpc.AgentSelectRequest{Name: name}); err != nil {
		return "", Handoff{}, err
	}
	data, err := json.Marshal(message)
	if err != nil {
		return "", Handoff{}, err
	}
	response, err := waitForResponse(ctx, message.Session, copilot.MessageOptions{Prompt: string(data), Source: copilot.MessageSourceAgent(name)}, map[string]any{
		environmentDetectorName: Handoff{},
		plannerName:             Handoff{},
	})
	if err != nil {
		return "", Handoff{}, err
	}
	if _, err := message.Session.RPC.History.Compact(ctx, &rpc.SessionHistoryCompactRequest{}); err != nil {
		return "", Handoff{}, err
	}
	for edge, raw := range response {
		var next Handoff
		if err := json.Unmarshal(raw, &next); err != nil {
			return "", Handoff{}, err
		}
		if err := next.validate(); err != nil {
			return "", Handoff{}, err
		}
		next.Session = message.Session
		return edge, next, nil
	}
	return "", Handoff{}, errors.New("Triplet Editor returned without a route")
}

type BaselineUpdater struct{}

func (updater *BaselineUpdater) Run(ctx context.Context, input <-chan Handoff, reports chan<- Handoff, errorsOut chan<- error, wait *sync.WaitGroup) {
	defer wait.Done()
	for {
		var message Handoff
		select {
		case <-ctx.Done():
			return
		case received := <-input:
			message = received
		}

		_, next, err := updater.update(ctx, message)
		if err != nil {
			errorsOut <- fmt.Errorf("%s: %w", baselineUpdaterName, err)
			return
		}
		slog.Info("handoff", "agent", baselineUpdaterName, "target", plannerName)
		if err := send(ctx, reports, next); err != nil {
			errorsOut <- fmt.Errorf("%s: %w", baselineUpdaterName, err)
			return
		}
	}
}

func (updater *BaselineUpdater) update(ctx context.Context, message Handoff) (string, Handoff, error) {
	name := baselineUpdaterName
	activeAgent.Store(&name)
	activeMessage.Store(&message)
	if _, err := message.Session.RPC.Agent.Select(ctx, &rpc.AgentSelectRequest{Name: name}); err != nil {
		return "", Handoff{}, err
	}
	data, err := json.Marshal(message)
	if err != nil {
		return "", Handoff{}, err
	}
	response, err := waitForResponse(ctx, message.Session, copilot.MessageOptions{Prompt: string(data), Source: copilot.MessageSourceAgent(name)}, map[string]any{
		plannerName: Handoff{},
	})
	if err != nil {
		return "", Handoff{}, err
	}
	if _, err := message.Session.RPC.History.Compact(ctx, &rpc.SessionHistoryCompactRequest{}); err != nil {
		return "", Handoff{}, err
	}
	for edge, raw := range response {
		var next Handoff
		if err := json.Unmarshal(raw, &next); err != nil {
			return "", Handoff{}, err
		}
		if err := next.validate(); err != nil {
			return "", Handoff{}, err
		}
		next.Session = message.Session
		return edge, next, nil
	}
	return "", Handoff{}, errors.New("Baseline Updater returned without a route")
}

type commandParams struct {
	Tool      string   `json:"tool"`
	Args      []string `json:"args"`
	Directory string   `json:"directory,omitempty"`
}
type commandResult struct {
	ExitCode int    `json:"exitCode"`
	Log      string `json:"log"`
}

func executeTool(config *RuntimeConfig, role string, message Handoff, params commandParams, ctx context.Context) (commandResult, error) {
	if err := checkCommand(config, role, message, params); err != nil {
		return commandResult{}, err
	}
	directory := params.Directory
	if directory == "" {
		directory = config.Workspace
	}
	args := slices.Clone(params.Args)
	if params.Tool == "vcpkg" {
		args = append(args, config.vcpkgArgs("", false)...)
		if config.ManifestRoot != "" {
			args = append(args, "--x-manifest-root="+config.ManifestRoot)
		}
	}
	file, err := os.CreateTemp(config.LogDirectory, params.Tool+"-*.log")
	if err != nil {
		return commandResult{}, err
	}
	writer := &safeLogWriter{file: file, secrets: config.SecretValues}
	defer writer.Close()
	command := exec.CommandContext(ctx, config.Tools[params.Tool], args...)
	command.Dir = directory
	command.Env = config.VcpkgEnv
	if params.Tool == "gh" {
		command.Env = os.Environ()
	}
	command.Stdout, command.Stderr = writer, writer
	slog.Info("command", "agent", role, "tool", params.Tool, "log", file.Name())
	err = command.Run()
	result := commandResult{ExitCode: -1, Log: file.Name()}
	if command.ProcessState != nil {
		result.ExitCode = command.ProcessState.ExitCode()
	}
	var exited *exec.ExitError
	if errors.As(err, &exited) {
		return result, nil
	}
	return result, err
}
func writePaths(config *RuntimeConfig, role string, message Handoff) []string {
	if isDryRunPrompt(config.Options.Prompt) {
		return nil
	}
	var roots []string
	switch role {
	case portEditorName:
		roots = append(roots, config.Scratch)
		if len(message.Ports) == 1 {
			port := strings.SplitN(message.Ports[0], "[", 2)[0]
			if validName(port) && config.allowed("ports") && config.Scenario == "registry" {
				roots = append(roots, filepath.Join(config.Workspace, "ports", port))
			}
			if validName(port) && config.allowed("overlays") {
				for _, overlay := range config.OverlayPorts {
					roots = append(roots, filepath.Join(overlay, port))
				}
			}
		}
		if config.Scenario == "manifest" && config.allowed("manifest") {
			roots = append(roots, filepath.Join(config.ManifestRoot, "vcpkg.json"), filepath.Join(config.ManifestRoot, "vcpkg-configuration.json"))
		}
	case tripletEditorName:
		if validName(message.Triplet) && (config.allowed("triplets") || config.allowed("overlays")) {
			for _, overlay := range config.OverlayTriplets {
				roots = append(roots, filepath.Join(overlay, message.Triplet+".cmake"))
			}
		}
	case baselineUpdaterName:
		if config.Scenario != "registry" {
			return nil
		}
		for _, port := range message.Ports {
			if !validName(port) {
				continue
			}
			if config.allowed("ports") {
				roots = append(roots, filepath.Join(config.Workspace, "ports", port))
			}
			if config.allowed("versions") {
				roots = append(roots, filepath.Join(config.Workspace, "versions", port[:1]+"-", port+".json"))
			}
		}
		if config.allowed("versions") && len(message.Ports) > 0 {
			roots = append(roots, filepath.Join(config.Workspace, "versions", "baseline.json"))
		}
	}
	return roots
}
func validName(name string) bool {
	if name == "" {
		return false
	}
	for _, letter := range name {
		if letter != '-' && (letter < 'a' || letter > 'z') && (letter < '0' || letter > '9') {
			return false
		}
	}
	return true
}
func checkCommand(config *RuntimeConfig, role string, message Handoff, params commandParams) error {
	directory, err := checkCommandInput(config, params)
	if err != nil {
		return err
	}
	switch params.Tool {
	case "vcpkg":
		return checkVcpkgCommand(config, role, message, params)
	case "git":
		return checkGitCommand(config, role, message, params, directory)
	case "gh":
		if (role == portDoctorName || role == portEditorName || role == environmentDetectorName) && isReadOnlyGH(params.Args) {
			return nil
		}
	default:
		if role == environmentDetectorName && len(params.Args) == 1 && (params.Args[0] == "--version" || params.Args[0] == "--help") {
			return nil
		}
	}
	return fmt.Errorf("%s cannot run %s %s", role, params.Tool, params.Args[0])
}

func checkCommandInput(config *RuntimeConfig, params commandParams) (string, error) {
	if config.Tools[params.Tool] == "" || len(params.Args) == 0 {
		return "", errors.New("registered tool and arguments are required")
	}
	directory := params.Directory
	if directory == "" {
		directory = config.Workspace
	}
	if !insideAny(directory, configReadRoots(config)) {
		return "", errors.New("command directory is outside allowed folders")
	}
	for _, arg := range params.Args {
		if strings.ContainsAny(arg, "\x00\r\n") && params.Tool != "git" {
			return "", errors.New("multiline command arguments are restricted to git commit messages")
		}
		if strings.HasPrefix(arg, "--debug") || strings.HasPrefix(arg, "--binarysource") || strings.HasPrefix(arg, "--x-asset-sources") || strings.HasPrefix(arg, "--overlay-") || strings.HasPrefix(arg, "--downloads-root") || strings.HasPrefix(arg, "--vcpkg-root") || strings.HasPrefix(arg, "--x-buildtrees-root") || strings.HasPrefix(arg, "--x-packages-root") || strings.HasPrefix(arg, "--x-install-root") || strings.HasPrefix(arg, "--x-manifest-root") || strings.HasPrefix(arg, "--feature-flags") || arg == "--editable" || arg == "--allow-unsupported" {
			return "", errors.New("tool roots, caches and environment are fixed at initialization")
		}
	}
	return directory, nil
}

func checkVcpkgCommand(config *RuntimeConfig, role string, message Handoff, params commandParams) error {
	subcommand := params.Args[0]
	if slices.Contains([]string{"help", "version", "--version", "z-print-config", "list", "search", "depend-info", "x-package-info"}, subcommand) {
		return nil
	}
	switch role {
	case environmentDetectorName:
		if subcommand == "x-set-installed" && slices.Contains(params.Args, "--dry-run") {
			return nil
		}
	case portInstallerName:
		if subcommand == "install" && (!isDryRunPrompt(config.Options.Prompt) || slices.Contains(params.Args, "--dry-run")) {
			return nil
		}
		if subcommand == "remove" && config.Scenario == "registry" && !isDryRunPrompt(config.Options.Prompt) {
			return nil
		}
	case portEditorName:
		if subcommand == "hash" && len(params.Args) > 1 && insideAny(params.Args[1], configReadRoots(config)) {
			return nil
		}
		if subcommand == "create" && len(params.Args) >= 3 && len(message.Ports) == 1 && params.Args[1] == message.Ports[0] && allowURL(params.Args[2], []string{"*"}) {
			if insideAny(filepath.Join(config.Workspace, "ports", params.Args[1]), writePaths(config, role, message)) {
				return nil
			}
		}
	case baselineUpdaterName:
		if subcommand == "format-manifest" && len(params.Args) == 2 && insideAny(params.Args[1], writePaths(config, role, message)) {
			return nil
		}
		if subcommand == "x-add-version" && len(params.Args) > 1 && slices.Contains(message.Ports, params.Args[1]) && config.allowed("versions") {
			return nil
		}
	}
	return fmt.Errorf("%s cannot run vcpkg %s", role, subcommand)
}

func checkGitCommand(config *RuntimeConfig, role string, message Handoff, params commandParams, directory string) error {
	subcommand := params.Args[0]
	if slices.Contains([]string{"status", "log", "show", "diff", "rev-parse", "ls-files", "cat-file", "diff-tree", "merge-base"}, subcommand) {
		for index, arg := range params.Args {
			if arg == "--output" && (index+1 == len(params.Args) || !insideAny(params.Args[index+1], writePaths(config, role, message))) {
				return errors.New("git output path is not writable")
			}
			if strings.HasPrefix(arg, "--output=") && !insideAny(strings.TrimPrefix(arg, "--output="), writePaths(config, role, message)) {
				return errors.New("git output path is not writable")
			}
			if arg == "--ext-diff" || strings.HasPrefix(arg, "--textconv") {
				return errors.New("external diff execution is restricted")
			}
		}
		return nil
	}
	if role == portEditorName && insideAny(directory, []string{config.Scratch}) && slices.Contains([]string{"init", "add", "commit", "apply"}, subcommand) {
		return nil
	}
	if role == baselineUpdaterName && config.allowed("commit") && samePath(directory, config.Workspace) {
		if subcommand == "add" && len(params.Args) > 2 && params.Args[1] == "--" {
			for _, path := range params.Args[2:] {
				absolute := path
				if !filepath.IsAbs(absolute) {
					absolute = filepath.Join(directory, path)
				}
				if !insideAny(absolute, writePaths(config, role, message)) {
					return errors.New("git add target is outside the requested files")
				}
				for _, dirty := range config.InitialDirty {
					if insideAny(dirty, []string{absolute}) {
						return errors.New("git add target contains existing user changes")
					}
				}
			}
			return nil
		}
		if subcommand == "commit" && len(params.Args) == 3 && params.Args[1] == "-m" && strings.Contains(params.Args[2], coauthorTrailer) {
			staged, err := exec.Command(config.Tools["git"], "-C", directory, "diff", "--cached", "--name-only", "-z").Output()
			if err != nil {
				return err
			}
			for _, path := range bytes.Split(bytes.TrimSuffix(staged, []byte{0}), []byte{0}) {
				absolute := filepath.Join(directory, string(path))
				if !insideAny(absolute, writePaths(config, role, message)) || containsPath(config.InitialDirty, absolute) {
					return errors.New("index contains files outside this verified change")
				}
			}
			return nil
		}
	}
	return fmt.Errorf("%s cannot run git %s", role, subcommand)
}

func (config *RuntimeConfig) redactToolResult(input copilot.PostToolUseHookInput, _ copilot.HookInvocation) (*copilot.PostToolUseHookOutput, error) {
	redacted := redactValue(input.ToolResult, config.SecretValues)
	if reflectEqual(input.ToolResult, redacted) {
		return nil, nil
	}
	return &copilot.PostToolUseHookOutput{ModifiedResult: redacted}, nil
}

// Manual SDK permissions wait for the host callback, which enforces initialized access boundaries.
func (config *RuntimeConfig) authorize(request copilot.PermissionRequest, _ copilot.PermissionInvocation) (rpc.PermissionDecision, error) {
	role, message := activeAgent.Load(), activeMessage.Load()
	if role == nil || message == nil {
		return &rpc.PermissionDecisionReject{}, nil
	}
	return config.authorizeRequest(*role, *message, request), nil
}

func (config *RuntimeConfig) authorizeRequest(role string, message Handoff, request copilot.PermissionRequest) rpc.PermissionDecision {
	approve := &rpc.PermissionDecisionApproveOnce{}
	reject := &rpc.PermissionDecisionReject{}
	switch request := request.(type) {
	case rpc.PermissionRequestRead:
		return config.authorizeRequest(role, message, &request)
	case rpc.PermissionRequestWrite:
		return config.authorizeRequest(role, message, &request)
	case rpc.PermissionRequestCustomTool:
		return config.authorizeRequest(role, message, &request)
	case rpc.PermissionRequestURL:
		return config.authorizeRequest(role, message, &request)
	case rpc.PermissionRequestMCP:
		return config.authorizeRequest(role, message, &request)
	case *rpc.PermissionRequestRead:
		if insideAny(request.Path, configReadRoots(config)) {
			return approve
		}
	case *rpc.PermissionRequestWrite:
		if insideAny(request.FileName, writePaths(config, role, message)) {
			return approve
		}
	case *rpc.PermissionRequestCustomTool:
		for _, agent := range agentDefinitions {
			if agent.Name == role && slices.Contains(agent.Tools, request.ToolName) {
				return approve
			}
		}
	case *rpc.PermissionRequestURL:
		if (role == portDoctorName || role == portEditorName || role == tripletEditorName) && allowURL(request.URL, []string{"*"}) {
			return approve
		}
	case *rpc.PermissionRequestMCP:
		if request.ServerName == microsoftLearnMCPName && request.ReadOnly && (role == portDoctorName || role == tripletEditorName) {
			return approve
		}
	}
	return reject
}
func sessionOptions(config *RuntimeConfig) *copilot.CreateSessionOptions {
	var available []string
	for _, agent := range agentDefinitions {
		available = append(available, agent.Tools...)
	}
	facts, _ := json.Marshal(map[string]any{"scenario": config.Scenario, "workspace": config.Workspace, "manifestRoot": config.ManifestRoot, "roots": config.Roots, "overlayPorts": config.OverlayPorts, "overlayTriplets": config.OverlayTriplets, "tools": config.Tools, "variables": config.Variables, "warnings": config.Warnings, "blockers": config.Blockers, "writePermissions": config.WriteScopes, "scratch": config.Scratch, "logDirectory": config.LogDirectory, "coauthorTrailer": coauthorTrailer, "maxPortCycles": config.Options.MaxPortCycles, "maxTripletEdits": config.Options.MaxTripletEdits, "userRequest": config.Options.Prompt})
	return &copilot.CreateSessionOptions{ClientName: "vcpkg-agents", Model: config.Options.Model, WorkingDirectory: config.Workspace, EnableConfigDiscovery: copilot.Bool(false), Filesystem: copilot.CreateSessionFilesystemOptions{TrustWorkingDirectory: copilot.WorkingDirectoryTrustSession, AdditionalDirectories: configReadRoots(config)}, Instructions: copilot.CreateSessionInstructionOptions{OnDemandDiscovery: copilot.Bool(false), SkipCustomInstructions: copilot.Bool(true)}, Hooks: copilot.SessionHookOptions{EnableRepositoryHooks: copilot.Bool(false), Handlers: &copilot.SessionHooks{OnPostToolUse: config.redactToolResult}}, Git: copilot.SessionGitOptions{EnableHostGitOperations: copilot.Bool(false), CoauthorEnabled: copilot.Bool(false)}, Skills: copilot.SessionSkillOptions{Enabled: copilot.Bool(false), IncludedBuiltinSkills: []string{}}, Agents: copilot.SessionAgentOptions{Definitions: agentDefinitions, Selected: plannerName, LocalDiscoveryOnly: copilot.Bool(true), IncludedBuiltinAgents: []string{}}, Tools: copilot.SessionToolOptions{AvailableTools: uniqueStrings(available)}, Permissions: copilot.SessionPermissionOptions{Mode: rpc.PermissionModeManual, OnRequest: config.authorize}, MCP: copilot.SessionMCPOptions{Servers: map[string]copilot.MCPServerConfig{microsoftLearnMCPName: copilot.MCPHTTPServerConfig{URL: "https://learn.microsoft.com/api/mcp", Tools: []string{"microsoft_docs_search", "microsoft_docs_fetch"}}}}, SystemMessage: &copilot.SystemMessageConfig{Mode: "append", Content: sharedInstructions + "\nInitialized facts:\n" + redactText(string(facts), config.SecretValues)}}
}

func main() {
	os.Exit(run())
}

func run() int {
	config := configuration
	defer config.Cleanup()
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()
	runtimePath := ""
	if os.Getenv("COPILOT_CLI_PATH") != "" {
		runtimePath = config.Tools["copilot"]
	}
	client := copilot.NewClient(&copilot.ClientOptions{Mode: copilot.ModeCodingAgent, Runtime: copilot.SpawnedStdioConnection{Path: runtimePath, WorkingDirectory: config.Workspace}})
	if err := client.Start(ctx); err != nil {
		slog.Error("start SDK", "error", err)
		return 1
	}
	defer client.Stop()
	session, err := client.CreateSession(ctx, sessionOptions(config))
	if err != nil {
		slog.Error("create session", "error", err)
		return 1
	}
	defer session.Disconnect()
	slog.Info("session created", "session", session.SessionID, "model", config.Options.Model)
	userRequests := make(chan Handoff)
	detectRequests := make(chan Handoff)
	environmentReports := make(chan Handoff)
	installRequests := make(chan Handoff)
	installReports := make(chan Handoff)
	installFailures := make(chan Handoff)
	portGoals := make(chan Handoff)
	tripletGoals := make(chan Handoff)
	blockers := make(chan Handoff)
	retries := make(chan Handoff)
	reinstalls := make(chan Handoff)
	hostRequests := make(chan Handoff)
	hostFacts := make(chan Handoff)
	baselineRequests := make(chan Handoff)
	baselineReports := make(chan Handoff)
	final := make(chan FinalReport)
	errorsOut := make(chan error, 7)
	planner := &Planner{}
	detector := &EnvironmentDetector{}
	installer := &PortInstaller{}
	doctor := &PortDoctor{}
	editor := &PortEditor{}
	triplet := &TripletEditor{}
	baseline := &BaselineUpdater{}
	tools := copilot.DefineTool("execute_tool", "Run a registered CLI with argument array. Returns exitCode and the path of its unmodified output log. Configured vcpkg roots are added automatically.", func(params commandParams, _ copilot.ToolInvocation) (commandResult, error) {
		role, message := activeAgent.Load(), activeMessage.Load()
		if role == nil || message == nil {
			return commandResult{}, errors.New("active agent required")
		}
		return executeTool(config, *role, *message, params, ctx)
	})
	if err := session.SetTools(ctx, []copilot.Tool{tools}); err != nil {
		slog.Error("register tools", "error", err)
		return 1
	}
	var wait sync.WaitGroup
	wait.Add(7)
	go planner.Run(ctx, userRequests, environmentReports, installReports, blockers, reinstalls, baselineReports,
		detectRequests, installRequests, baselineRequests, final, errorsOut, &wait)
	go detector.Run(ctx, detectRequests, hostRequests, environmentReports, hostFacts, errorsOut, &wait)
	go installer.Run(ctx, installRequests, retries, installFailures, installReports, errorsOut, &wait)
	go doctor.Run(ctx, installFailures, portGoals, tripletGoals, blockers, errorsOut, &wait)
	go editor.Run(ctx, portGoals, retries, errorsOut, &wait)
	go triplet.Run(ctx, tripletGoals, hostFacts, hostRequests, reinstalls, errorsOut, &wait)
	go baseline.Run(ctx, baselineRequests, baselineReports, errorsOut, &wait)
	if err := send(ctx, userRequests, Handoff{Session: session, Goal: startup.Prompt, Evidence: []string{"initialized environment facts and original user request"}}); err != nil {
		errorsOut <- err
	}
	var report FinalReport
	select {
	case report = <-final:
	case err = <-errorsOut:
	case <-ctx.Done():
		err = ctx.Err()
	}
	cancel()
	wait.Wait()
	close(errorsOut)
	for remaining := range errorsOut {
		if !errors.Is(remaining, context.Canceled) {
			err = errors.Join(err, remaining)
		}
	}
	if err != nil {
		slog.Error("agents", "error", err)
	}
	if report.Status != "" {
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetIndent("", "  ")
		if encodeErr := encoder.Encode(report); encodeErr != nil {
			slog.Error("final report", "error", encodeErr)
			err = errors.Join(err, encodeErr)
		}
	}
	if usage, usageErr := session.RPC.Usage.GetMetrics(context.Background()); usageErr == nil {
		credits := 0.0
		if usage.TotalNanoAiu != nil {
			credits = *usage.TotalNanoAiu / 1e9
		}
		slog.Info("usage", "session", session.SessionID, "ai_credits", credits)
	}
	if err == nil && report.Status == "finished" {
		return 0
	}
	return 1
}
