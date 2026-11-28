package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha512"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	copilot "github.com/microsoft/copilot-sdk/go/v2"
	"github.com/microsoft/copilot-sdk/go/v2/rpc"
)

const (
	defaultModel          = "gpt-6-luna"
	maxQueuedInstalls     = 16
	commandTimeout        = 2 * time.Minute
	installTimeout        = 24 * time.Hour
	maxModelLogBytes      = 64 << 10
	maxCommandSummary     = 16 << 10
	coauthorTrailer       = "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
	microsoftLearnMCPName = "microsoft-learn"
)

const teamPrompt = `
You are one member of a seven-member vcpkg team.
The team shares one Copilot session. One member takes a turn at a time.
Work only toward the goal in the message. Never provide step-by-step work to another member.
Ground every fact in a path, line, URL, issue, or command result.
End every turn by calling exactly one send_* handoff tool.
Put all evidence the next member needs in Goal and Evidence.
Never expose secret values. Never push, open an issue, create a pull request, or write to a remote service.
Never run vcpkg with --debug or --debug-env. Never run the gh issue create command printed by vcpkg.
Binary cache failures are warnings. Do not disable binary caching to work around a failure.
`

const plannerPrompt = `
You are Planner. Delegate environment detection first. Build an ordered install plan from triplets, ports, and features.
Judge whether reports satisfy the original request. Do not write files and do not run commands.
Call send_detect_request, send_install_requests, send_baseline_request, or send_final_report.
Copy the deterministic payload in the turn prompt. Do not invent paths, ports, commits, or facts.
`

const environmentDetectorPrompt = `
You are Environment Detector. Report the scenario, roots, overlays, tools, triplets, variables, compiler facts, and blockers.
Read-only except for transient access probes done by Go tools. Call send_env_report or send_host_facts.
Copy the deterministic payload in the turn prompt. Do not print secret values.
`

const portInstallerPrompt = `
You are Port Installer. The Go harness runs vcpkg stages serially and gives you the exact result.
Do not run shell tools. Call send_install_failure for a failed stage, or send_install_report when the stack is complete.
Copy the payload in the turn prompt. Preserve command, exit code, result code, and log paths exactly.
`

const portDoctorPrompt = `
You are Port Doctor. Diagnose the failure from logs and source. Classify build configuration, toolchain, installation, or misc.
Separate facts, observations, and interpretations, and cite every one.
Route one result: send_port_goals for a writable port fix, send_triplet_goals for a triplet fix,
or send_blocker when no allowed fix exists. Do not edit files.
`

const portEditorPrompt = `
You are Port Editor. Change only the target port, manifest files allowed by the current scope, or the scratch folder.
For patches, use prepare_patch, edit the scratch copy, then make_patch. Verify the patch.
Update version or port-version only when needed and not already changed.
After the smallest verified change, call send_retry_request with changed paths.
`

const tripletEditorPrompt = `
You are Triplet Editor. Change only a writable overlay triplet. A built-in triplet needs an overlay copy.
Ask for host facts with send_host_facts_request only when host details are necessary.
After one verified change, call send_reinstall_request. State the triplet ABI impact.
`

const baselineUpdaterPrompt = `
You are Baseline Updater. Work on one port at a time, in the order supplied.
Run version_update with stage "format", commit the target port folder, then run version_update with stage "versions".
Commit versions after the tree guard passes. Use git_commit. Never amend and never push.
Call send_baseline_report with the resulting local commits and skipped ports.
`

const (
	plannerName             = "planner"
	environmentDetectorName = "environment-detector"
	portInstallerName       = "port-installer"
	portDoctorName          = "port-doctor"
	portEditorName          = "port-editor"
	tripletEditorName       = "triplet-editor"
	baselineUpdaterName     = "baseline-updater"
)

type multiFlag []string

func (f *multiFlag) String() string {
	return strings.Join(*f, string(os.PathListSeparator))
}

func (f *multiFlag) Set(value string) error {
	*f = append(*f, value)
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
	Write           []string
	MaxPortCycles   int
	MaxTripletEdits int
	LockWait        time.Duration
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
	fs.Var(&writes, "write", "write scope: ports,triplets,versions,manifest,overlays,create-overlays,commit; repeatable")
	fs.IntVar(&options.MaxPortCycles, "max-port-cycles", 3, "maximum failed cycles per port")
	fs.IntVar(&options.MaxTripletEdits, "max-triplet-edits", 1, "maximum triplet edits per triplet")
	fs.DurationVar(&options.LockWait, "lock-wait", 10*time.Minute, "maximum vcpkg lock wait")
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
	allowedWriteScopes := map[string]bool{
		"ports": true, "triplets": true, "versions": true, "manifest": true,
		"overlays": true, "create-overlays": true, "commit": true,
	}
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
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
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
	toolPaths["copilot"] = copilotPath

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
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, vcpkgPath, printArgs...)
	cmd.Dir = wd
	cmd.Env = env
	printOutput, printErr := cmd.CombinedOutput()

	var printed zPrintConfig
	_ = json.Unmarshal(printOutput, &printed)
	roots := VcpkgRoots{
		Vcpkg:      cleanPath(firstNonEmpty(printed.VcpkgRoot, options.VcpkgRoot, os.Getenv("VCPKG_ROOT"))),
		Buildtrees: cleanPath(firstNonEmpty(printed.Buildtrees, options.BuildtreesRoot)),
		Downloads:  cleanPath(printed.Downloads),
		Installed:  cleanPath(firstNonEmpty(printed.Installed, options.InstallRoot)),
		Packages:   cleanPath(firstNonEmpty(printed.Packages, options.PackagesRoot)),
	}
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
	if err := os.MkdirAll(logDirectory, 0o700); err != nil {
		return nil, err
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
		detectionError = redactText(fmt.Sprintf("vcpkg z-print-config: %v: %s", printErr, printOutput), secretValues)
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

	config := &RuntimeConfig{
		Options:          options,
		WorkingDirectory: wd,
		Workspace:        workspace,
		ManifestRoot:     manifestRoot,
		Scenario:         scenario,
		ScenarioEvidence: scenarioEvidence,
		Tools:            toolPaths,
		Roots:            roots,
		OverlayPorts:     overlays,
		OverlayTriplets:  overlayTriplets,
		DefaultTriplet:   firstNonEmpty(printed.DefaultTriplet, os.Getenv("VCPKG_DEFAULT_TRIPLET")),
		HostTriplet:      printed.HostTriplet,
		Variables:        variables,
		DetectionError:   detectionError,
		Warnings:         uniqueStrings(warnings),
		Blockers:         uniqueStrings(blockers),
		SecretValues:     secretValues,
		VcpkgEnv:         env,
		InitialDirty:     gitDirtyPaths(workspace, toolPaths["git"]),
		Scratch:          scratch,
		LogDirectory:     logDirectory,
		WriteScopes:      writeScopes,
		RunID:            filepath.Base(scratch),
	}
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
		return "", errors.New("Copilot CLI was not found on PATH")
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
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if output, err := exec.CommandContext(ctx, gitPath, "-C", workspace, "rev-parse", "--is-inside-work-tree").CombinedOutput(); err != nil || strings.TrimSpace(string(output)) != "true" {
		return []string{"registry is not a git working tree"}
	}
	var blockers []string
	output, err := exec.CommandContext(ctx, gitPath, "-C", workspace, "config", "--get", "core.autocrlf").Output()
	autocrlf := strings.TrimSpace(string(output))
	if runtime.GOOS == "windows" && err == nil && strings.EqualFold(autocrlf, "true") {
		blockers = append(blockers, "core.autocrlf=true can make vcpkg x-add-version record a different port tree")
	}
	portsRoot := filepath.Join(workspace, "ports")
	_ = filepath.WalkDir(portsRoot, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil || entry.IsDir() {
			return walkErr
		}
		switch strings.ToLower(filepath.Ext(path)) {
		case ".json", ".cmake", ".patch", ".diff":
		default:
			return nil
		}
		data, err := os.ReadFile(path)
		if err == nil && bytes.Contains(data, []byte("\r\n")) {
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
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
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
	allowed := map[string]bool{
		"ports": true, "triplets": true, "versions": true, "manifest": true,
		"overlays": true, "create-overlays": true, "commit": true,
	}
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
	names := []string{
		"VCPKG_ROOT", "VCPKG_DOWNLOADS", "VCPKG_DEFAULT_TRIPLET", "VCPKG_DEFAULT_HOST_TRIPLET",
		"VCPKG_OVERLAY_PORTS", "VCPKG_OVERLAY_TRIPLETS", "VCPKG_BINARY_SOURCES",
		"VCPKG_DEFAULT_BINARY_CACHE", "VCPKG_BINARY_CACHE_COMPRESSION_LEVEL",
		"VCPKG_NUGET_REPOSITORY", "VCPKG_USE_NUGET_CACHE", "VCPKG_FEATURE_FLAGS",
		"VCPKG_KEEP_ENV_VARS", "VCPKG_MAX_CONCURRENCY", "VCPKG_FORCE_SYSTEM_BINARIES",
		"VCPKG_FORCE_DOWNLOADED_BINARIES", "VCPKG_DISABLE_METRICS", "VCPKG_NO_CI",
		"X_VCPKG_ASSET_SOURCES", "X_VCPKG_REGISTRIES_CACHE", "X_VCPKG_RECURSIVE_DATA",
	}
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
	names := []string{
		"VCPKG_BINARY_SOURCES", "X_VCPKG_ASSET_SOURCES", "X_VCPKG_RECURSIVE_DATA",
		"VCPKG_NUGET_REPOSITORY", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY",
		"http_proxy", "https_proxy", "all_proxy", "GITHUB_TOKEN", "GH_TOKEN",
	}
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
	keepExact := map[string]bool{
		"PATH": true, "PATHEXT": true, "SYSTEMROOT": true, "COMSPEC": true, "WINDIR": true,
		"HOME": true, "USERPROFILE": true, "HOMEDRIVE": true, "HOMEPATH": true,
		"TEMP": true, "TMP": true, "TMPDIR": true, "APPDATA": true, "LOCALAPPDATA": true,
		"XDG_CACHE_HOME": true, "XDG_CONFIG_HOME": true, "LANG": true, "LC_ALL": true,
		"CC": true, "CXX": true, "SDKROOT": true, "MACOSX_DEPLOYMENT_TARGET": true,
		"JAVA_HOME": true, "ANDROID_HOME": true, "ANDROID_NDK_HOME": true,
		"ANDROID_NDK": true, "ANDROID_NDK_ROOT": true, "NDK_ROOT": true,
		"VULKAN_SDK": true, "ONEAPI_ROOT": true, "CUDA_TOOLKIT_ROOT_DIR": true,
		"GIT_SSH": true, "GIT_ASKPASS": true, "SSH_AUTH_SOCK": true,
		"HTTP_PROXY": true, "HTTPS_PROXY": true, "ALL_PROXY": true, "NO_PROXY": true,
		"http_proxy": true, "https_proxy": true, "all_proxy": true, "no_proxy": true,
		"CURL_CA_BUNDLE": true, "SSL_CERT_FILE": true, "SSL_CERT_DIR": true,
		"PKG_CONFIG_PATH": true, "CMAKE_PREFIX_PATH": true, "CMAKE_TOOLCHAIN_FILE": true,
	}
	vcpkgNames := map[string]bool{
		"VCPKG_ROOT": true, "VCPKG_DOWNLOADS": true, "VCPKG_DEFAULT_TRIPLET": true,
		"VCPKG_DEFAULT_HOST_TRIPLET": true, "VCPKG_OVERLAY_PORTS": true,
		"VCPKG_OVERLAY_TRIPLETS": true, "VCPKG_BINARY_SOURCES": true,
		"VCPKG_DEFAULT_BINARY_CACHE": true, "VCPKG_BINARY_CACHE_COMPRESSION_LEVEL": true,
		"VCPKG_NUGET_REPOSITORY": true, "VCPKG_USE_NUGET_CACHE": true,
		"VCPKG_FEATURE_FLAGS": true, "VCPKG_KEEP_ENV_VARS": true,
		"VCPKG_MAX_CONCURRENCY": true, "VCPKG_FORCE_SYSTEM_BINARIES": true,
		"VCPKG_FORCE_DOWNLOADED_BINARIES": true, "VCPKG_DISABLE_METRICS": true,
		"VCPKG_NO_CI": true, "VCPKG_VISUAL_STUDIO_PATH": true,
		"X_VCPKG_ASSET_SOURCES": true, "X_VCPKG_REGISTRIES_CACHE": true,
		"X_VCPKG_RECURSIVE_DATA": true, "X_VCPKG_NUGET_ID_PREFIX": true,
		"VCPKG_ENV_PASSTHROUGH": true, "VCPKG_ENV_PASSTHROUGH_UNTRACKED": true,
	}
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
		keep := keepExact[name] || vcpkgNames[upper] || keepFromTriplet[name] ||
			strings.HasPrefix(upper, "PROGRAMFILES") || strings.HasPrefix(upper, "COMMONPROGRAMFILES") ||
			strings.HasPrefix(upper, "CUDA_PATH")
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

var secretPatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?i)([?&](?:sig|token|key|secret|password|passwd|credential)=)[^&\s]+`),
	regexp.MustCompile(`(?i)\b(authorization|token|secret|password|passwd|credential)\s*[:=]\s*[^\s,;]+`),
	regexp.MustCompile(`\bgh[pousr]_[A-Za-z0-9_]{16,}\b`),
	regexp.MustCompile(`\bgithub_pat_[A-Za-z0-9_]{16,}\b`),
	regexp.MustCompile(`\bAKIA[0-9A-Z]{16}\b`),
}

func redactText(text string, known []string) string {
	for _, secret := range known {
		if len(secret) < 6 {
			continue
		}
		text = strings.ReplaceAll(text, secret, "***SECRET***")
	}
	for _, pattern := range secretPatterns {
		text = pattern.ReplaceAllStringFunc(text, func(match string) string {
			if parts := strings.IndexAny(match, "=:"); parts >= 0 {
				return match[:parts+1] + "***SECRET***"
			}
			return "***SECRET***"
		})
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

type ShellRule struct {
	Program  string
	Prefix   []string
	ReadOnly bool
}

type Scope struct {
	CWD     string
	Read    []string
	Write   []string
	Shell   []ShellRule
	Network []string
	ToolCWD string
}

func (s Scope) Clone() Scope {
	return Scope{
		CWD: s.CWD, Read: append([]string(nil), s.Read...), Write: append([]string(nil), s.Write...),
		Shell: append([]ShellRule(nil), s.Shell...), Network: append([]string(nil), s.Network...), ToolCWD: s.ToolCWD,
	}
}

type Member struct {
	Name        string
	DisplayName string
	Prompt      string
	Tools       []string
	Deadline    time.Duration
	MaxTurns    uint32
	Network     []string
	BaseScope   Scope
	scope       atomic.Pointer[Scope]
	out         chan any
}

func newMember(name, display, prompt string, tools []string, deadline time.Duration, maxTurns uint32, scope Scope) *Member {
	member := &Member{
		Name: name, DisplayName: display, Prompt: prompt,
		Tools: append([]string(nil), tools...), Deadline: deadline, MaxTurns: maxTurns,
		Network: append([]string(nil), scope.Network...), BaseScope: scope, out: make(chan any, 1),
	}
	member.setScope(scope)
	return member
}

func (m *Member) setScope(scope Scope) {
	scope = scope.Clone()
	m.scope.Store(&scope)
}

func (m *Member) Scope() Scope {
	if scope := m.scope.Load(); scope != nil {
		return scope.Clone()
	}
	return m.BaseScope.Clone()
}

func (m *Member) withScope(scope Scope) func() {
	previous := m.Scope()
	m.setScope(scope)
	return func() { m.setScope(previous) }
}

func (m *Member) hasTool(name string) bool {
	return slices.Contains(m.Tools, name)
}

func configReadRoots(config *RuntimeConfig) []string {
	roots := []string{config.Workspace, config.WorkingDirectory, config.ManifestRoot, config.Scratch,
		config.Roots.Vcpkg, config.Roots.Buildtrees, config.Roots.Downloads, config.Roots.Installed, config.Roots.Packages}
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

func (c *RuntimeConfig) baseScope(network []string) Scope {
	return Scope{CWD: c.Workspace, Read: configReadRoots(c), Network: network}
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

type Handoff struct {
	Session  *copilot.Session `json:"-"`
	Goal     string           `json:"goal" jsonschema:"What the receiver must achieve; goals, not steps."`
	Evidence []string         `json:"evidence" jsonschema:"Paths, URLs, issues, and command outputs the receiver needs."`
}

func (h *Handoff) setSession(session *copilot.Session) {
	h.Session = session
}

type UserRequest struct {
	Handoff
	Prompt string `json:"prompt"`
}

type DetectRequest struct {
	Handoff
	Triplets []string `json:"triplets"`
	Features []string `json:"features"`
}

type EnvReport struct {
	Handoff
	Scenario         string           `json:"scenario"`
	ScenarioEvidence []string         `json:"scenarioEvidence"`
	Roots            VcpkgRoots       `json:"roots"`
	OverlayPorts     []string         `json:"overlayPorts"`
	OverlayTriplets  []string         `json:"overlayTriplets"`
	Triplets         []TripletFile    `json:"triplets"`
	Tools            []ToolInfo       `json:"tools"`
	Variables        []VariableStatus `json:"variables"`
	Writable         []string         `json:"writable,omitempty"`
	HostOS           string           `json:"hostOS"`
	HostArch         string           `json:"hostArch"`
	Web              bool             `json:"web"`
	Warnings         []string         `json:"warnings,omitempty"`
	Blockers         []string         `json:"blockers,omitempty"`
	PortsHint        []string         `json:"portsHint,omitempty"`
	DryRunOnly       bool             `json:"dryRunOnly"`
}

type InstallRequest struct {
	Handoff
	Triplet      string   `json:"triplet"`
	Ports        []string `json:"ports,omitempty"`
	Features     []string `json:"features,omitempty"`
	ManifestRoot string   `json:"manifestRoot,omitempty"`
	Reason       string   `json:"reason"`
	DryRunOnly   bool     `json:"dryRunOnly,omitempty"`
	Final        bool     `json:"final,omitempty"`
	SkipSpec     string   `json:"skipSpec,omitempty"`
}

type InstallBatch struct {
	Handoff
	Requests []InstallRequest `json:"requests"`
}

type SpecResult struct {
	Spec      string   `json:"spec"`
	Triplet   string   `json:"triplet"`
	Stage     string   `json:"stage"`
	Installed bool     `json:"installed"`
	Changed   bool     `json:"changed,omitempty"`
	Evidence  []string `json:"evidence,omitempty"`
}

type Unresolved struct {
	Spec     string   `json:"spec"`
	Triplet  string   `json:"triplet"`
	Reason   string   `json:"reason"`
	Evidence []string `json:"evidence,omitempty"`
}

type InstallReport struct {
	Handoff
	Done         []SpecResult `json:"done"`
	Unresolved   []Unresolved `json:"unresolved,omitempty"`
	ChangedPorts []string     `json:"changedPorts,omitempty"`
	DryRunOnly   bool         `json:"dryRunOnly"`
}

type InstallFailure struct {
	Handoff
	Spec         string   `json:"spec"`
	Triplet      string   `json:"triplet"`
	Stage        string   `json:"stage"`
	ExitCode     int      `json:"exitCode"`
	ResultCode   string   `json:"resultCode"`
	Command      string   `json:"command"`
	ErrorLogs    []string `json:"errorLogs,omitempty"`
	IssueBody    string   `json:"issueBody,omitempty"`
	OutputLog    string   `json:"outputLog"`
	Attempt      int      `json:"attempt"`
	Scenario     string   `json:"scenario"`
	ManifestRoot string   `json:"manifestRoot,omitempty"`
	Features     []string `json:"features,omitempty"`
}

type Finding struct {
	Kind   string `json:"kind"`
	Text   string `json:"text"`
	Source string `json:"source"`
}

type PortGoals struct {
	Handoff
	Port         string    `json:"port"`
	Spec         string    `json:"spec"`
	Triplet      string    `json:"triplet"`
	PortRoot     string    `json:"portRoot,omitempty"`
	Goals        []string  `json:"goals"`
	Diagnosis    []Finding `json:"diagnosis"`
	NewPort      string    `json:"newPort,omitempty"`
	ManifestRoot string    `json:"manifestRoot,omitempty"`
}

type TripletGoals struct {
	Handoff
	TripletFile  string   `json:"tripletFile"`
	OverlayRoot  string   `json:"overlayRoot,omitempty"`
	Triplet      string   `json:"triplet"`
	Variables    []string `json:"variables"`
	Ports        []string `json:"ports,omitempty"`
	Features     []string `json:"features,omitempty"`
	ManifestRoot string   `json:"manifestRoot,omitempty"`
	Guidance     string   `json:"guidance"`
}

type Blocker struct {
	Handoff
	Spec     string    `json:"spec,omitempty"`
	Triplet  string    `json:"triplet,omitempty"`
	Category string    `json:"category"`
	Reason   string    `json:"reason"`
	Findings []Finding `json:"findings,omitempty"`
}

type RetryRequest struct {
	Handoff
	Spec         string   `json:"spec"`
	Triplet      string   `json:"triplet"`
	ChangedFiles []string `json:"changedFiles"`
	Reason       string   `json:"reason,omitempty"`
}

type ReinstallRequest struct {
	Handoff
	Triplet      string   `json:"triplet"`
	TripletFile  string   `json:"tripletFile"`
	Change       string   `json:"change"`
	Ports        []string `json:"ports"`
	ManifestRoot string   `json:"manifestRoot,omitempty"`
	Features     []string `json:"features,omitempty"`
	Blocked      bool     `json:"blocked,omitempty"`
	Reason       string   `json:"reason,omitempty"`
}

type HostFactsRequest struct {
	Handoff
	Question string       `json:"question"`
	Goals    TripletGoals `json:"goals"`
}

type HostFacts struct {
	Handoff
	HostTriplet string       `json:"hostTriplet"`
	Compilers   []string     `json:"compilers,omitempty"`
	SDKs        []string     `json:"sdks,omitempty"`
	Notes       []string     `json:"notes,omitempty"`
	Goals       TripletGoals `json:"goals"`
}

type BaselineRequest struct {
	Handoff
	Ports []string `json:"ports"`
}

type Commit struct {
	Hash    string   `json:"hash"`
	Subject string   `json:"subject"`
	Paths   []string `json:"paths,omitempty"`
}

type BaselineReport struct {
	Handoff
	Commits []Commit `json:"commits,omitempty"`
	Skipped []string `json:"skipped,omitempty"`
}

type LedgerEntry struct {
	Spec     string   `json:"spec"`
	Triplet  string   `json:"triplet"`
	Status   string   `json:"status"`
	Evidence []string `json:"evidence,omitempty"`
}

type FinalReport struct {
	Handoff
	Status   string        `json:"status"`
	Scenario string        `json:"scenario,omitempty"`
	Ledger   []LedgerEntry `json:"ledger,omitempty"`
	Commits  []Commit      `json:"commits,omitempty"`
	Warnings []string      `json:"warnings,omitempty"`
	Blockers []Blocker     `json:"blockers,omitempty"`
}

type Planner struct {
	*Member
	config           *RuntimeConfig
	userPrompt       string
	environment      *EnvReport
	pending          []InstallReport
	blockers         []Blocker
	reportStatus     string
	expectedInstalls int
	receivedInstalls int
	changedPorts     []string
}

func NewPlanner(config *RuntimeConfig) *Planner {
	scope := config.baseScope(nil)
	return &Planner{
		Member: newMember(plannerName, "Planner", plannerPrompt,
			[]string{"view", "glob", "rg", "vcpkg_help", "send_detect_request", "send_install_requests", "send_baseline_request", "send_final_report"},
			10*time.Minute, 8, scope),
		config: config,
	}
}

type EnvironmentDetector struct {
	*Member
	config *RuntimeConfig
}

func NewEnvironmentDetector(config *RuntimeConfig) *EnvironmentDetector {
	scope := config.baseScope([]string{"github.com", "api.github.com", "learn.microsoft.com"})
	scope.Write = append(scope.Write, config.Roots.Buildtrees, config.Roots.Downloads, config.Roots.Installed, config.Roots.Packages)
	return &EnvironmentDetector{
		Member: newMember(environmentDetectorName, "Environment Detector", environmentDetectorPrompt,
			[]string{"view", "glob", "rg", "probe_tool", "detect_environment", "detect_compiler", "vcpkg_query", "vcpkg_help", "gh_read", "send_env_report", "send_host_facts"},
			15*time.Minute, 10, scope),
		config: config,
	}
}

type PortInstaller struct {
	*Member
	config     *RuntimeConfig
	stack      []InstallRequest
	waiting    bool
	finalSeen  bool
	dryRunOnly bool
	attempts   map[string]int
	changed    []string
	done       []SpecResult
	unresolved []Unresolved
}

func NewPortInstaller(config *RuntimeConfig) *PortInstaller {
	scope := config.baseScope(nil)
	if config.ManifestRoot != "" {
		scope.CWD = config.ManifestRoot
	}
	return &PortInstaller{
		Member: newMember(portInstallerName, "Port Installer", portInstallerPrompt,
			[]string{"view", "glob", "rg", "vcpkg_query", "vcpkg_help", "vcpkg_remove", "vcpkg_install", "read_log", "send_install_failure", "send_install_report"},
			installTimeout, 8, scope),
		config: config, attempts: make(map[string]int),
	}
}

type PortDoctor struct {
	*Member
	config *RuntimeConfig
}

func NewPortDoctor(config *RuntimeConfig) *PortDoctor {
	scope := config.baseScope([]string{"*"})
	scope.Shell = []ShellRule{
		{Program: "git", Prefix: []string{"log"}, ReadOnly: true},
		{Program: "git", Prefix: []string{"show"}, ReadOnly: true},
		{Program: "git", Prefix: []string{"diff"}, ReadOnly: true},
	}
	return &PortDoctor{
		Member: newMember(portDoctorName, "Port Doctor", portDoctorPrompt,
			[]string{"view", "glob", "rg", "bash", "powershell", "read_log", "vcpkg_query", "vcpkg_help", "gh_read", "web_fetch",
				"mcp:microsoft-learn-microsoft_docs_search", "mcp:microsoft-learn-microsoft_docs_fetch",
				"send_port_goals", "send_triplet_goals", "send_blocker"},
			30*time.Minute, 32, scope),
		config: config,
	}
}

type PortEditor struct {
	*Member
	config *RuntimeConfig
}

func NewPortEditor(config *RuntimeConfig) *PortEditor {
	scope := config.baseScope([]string{"*"})
	scope.Write = append(scope.Write, config.Scratch)
	scope.Shell = []ShellRule{
		{Program: "git", Prefix: []string{"diff"}, ReadOnly: true},
		{Program: "git", Prefix: []string{"status"}, ReadOnly: true},
	}
	return &PortEditor{
		Member: newMember(portEditorName, "Port Editor", portEditorPrompt,
			[]string{"view", "glob", "rg", "edit", "create", "apply_patch", "bash", "powershell", "web_fetch", "gh_read",
				"vcpkg_create", "prepare_patch", "make_patch", "download_sha512", "vcpkg_help", "send_retry_request"},
			30*time.Minute, 40, scope),
		config: config,
	}
}

type TripletEditor struct {
	*Member
	config *RuntimeConfig
	edits  map[string]int
}

func NewTripletEditor(config *RuntimeConfig) *TripletEditor {
	scope := config.baseScope([]string{"learn.microsoft.com", "github.com", "api.github.com"})
	if config.allowed("triplets") {
		scope.Write = append(scope.Write, config.OverlayTriplets...)
	}
	return &TripletEditor{
		Member: newMember(tripletEditorName, "Triplet Editor", tripletEditorPrompt,
			[]string{"view", "glob", "rg", "edit", "create", "apply_patch", "web_fetch", "vcpkg_help",
				"mcp:microsoft-learn-microsoft_docs_search", "mcp:microsoft-learn-microsoft_docs_fetch",
				"send_reinstall_request", "send_host_facts_request"},
			20*time.Minute, 24, scope),
		config: config,
		edits:  make(map[string]int),
	}
}

type BaselineUpdater struct {
	*Member
	config *RuntimeConfig
}

func NewBaselineUpdater(config *RuntimeConfig) *BaselineUpdater {
	scope := config.baseScope(nil)
	if config.allowed("versions") {
		scope.Write = append(scope.Write, filepath.Join(config.Workspace, "versions"))
	}
	return &BaselineUpdater{
		Member: newMember(baselineUpdaterName, "Baseline Updater", baselineUpdaterPrompt,
			[]string{"view", "glob", "rg", "version_update", "git_commit", "vcpkg_help", "send_baseline_report"},
			30*time.Minute, 24, scope),
		config: config,
	}
}

type Edges struct {
	UserRequest      chan UserRequest
	DetectRequest    chan DetectRequest
	EnvReport        chan EnvReport
	InstallRequest   chan InstallRequest
	InstallFailure   chan InstallFailure
	RetryRequest     chan RetryRequest
	PortGoals        chan PortGoals
	TripletGoals     chan TripletGoals
	Blocker          chan Blocker
	ReinstallRequest chan ReinstallRequest
	HostFactsRequest chan HostFactsRequest
	HostFacts        chan HostFacts
	InstallReport    chan InstallReport
	BaselineRequest  chan BaselineRequest
	BaselineReport   chan BaselineReport
	FinalReport      chan FinalReport
	Errors           chan error
}

func newEdges() *Edges {
	return &Edges{
		UserRequest: make(chan UserRequest), DetectRequest: make(chan DetectRequest), EnvReport: make(chan EnvReport),
		InstallRequest: make(chan InstallRequest, maxQueuedInstalls), InstallFailure: make(chan InstallFailure),
		RetryRequest: make(chan RetryRequest), PortGoals: make(chan PortGoals), TripletGoals: make(chan TripletGoals),
		Blocker: make(chan Blocker), ReinstallRequest: make(chan ReinstallRequest),
		HostFactsRequest: make(chan HostFactsRequest), HostFacts: make(chan HostFacts),
		InstallReport: make(chan InstallReport), BaselineRequest: make(chan BaselineRequest),
		BaselineReport: make(chan BaselineReport), FinalReport: make(chan FinalReport), Errors: make(chan error, 64),
	}
}

func send[T any](ctx context.Context, ch chan<- T, value T) error {
	select {
	case ch <- value:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func reportError(edges *Edges, err error) {
	if err == nil {
		return
	}
	select {
	case edges.Errors <- err:
	default:
		slog.Error("error channel full", "error", err)
	}
}

type Team struct {
	config     *RuntimeConfig
	client     *copilot.Client
	session    *copilot.Session
	planner    *Planner
	detector   *EnvironmentDetector
	installer  *PortInstaller
	doctor     *PortDoctor
	editor     *PortEditor
	triplet    *TripletEditor
	baseline   *BaselineUpdater
	members    map[string]*Member
	tools      []copilot.Tool
	active     atomic.Pointer[Member]
	turnMu     sync.Mutex
	vcpkgMu    sync.Mutex
	commandSeq atomic.Uint64
	httpClient *http.Client
}

func NewTeam(config *RuntimeConfig) *Team {
	team := &Team{config: config, httpClient: http.DefaultClient}
	team.planner = NewPlanner(config)
	team.detector = NewEnvironmentDetector(config)
	team.installer = NewPortInstaller(config)
	team.doctor = NewPortDoctor(config)
	team.editor = NewPortEditor(config)
	team.triplet = NewTripletEditor(config)
	team.baseline = NewBaselineUpdater(config)
	team.members = map[string]*Member{
		plannerName: team.planner.Member, environmentDetectorName: team.detector.Member,
		portInstallerName: team.installer.Member, portDoctorName: team.doctor.Member,
		portEditorName: team.editor.Member, tripletEditorName: team.triplet.Member,
		baselineUpdaterName: team.baseline.Member,
	}
	team.tools = team.defineTools()
	return team
}

func (t *Team) CreateSession(ctx context.Context) error {
	t.client = copilot.NewClient(&copilot.ClientOptions{
		Mode: copilot.ModeCodingAgent,
		Runtime: copilot.SpawnedStdioConnection{
			Path: t.config.Tools["copilot"], WorkingDirectory: t.config.Workspace,
		},
	})
	if err := t.client.Start(ctx); err != nil {
		return fmt.Errorf("start Copilot CLI: %w", err)
	}
	options := t.sessionOptions()
	session, err := t.client.CreateSession(ctx, options)
	if err != nil {
		_ = t.client.Stop()
		return err
	}
	t.session = session
	slog.Info("session created", "session", session.SessionID, "model", t.config.Options.Model)
	return nil
}

func (t *Team) Close() {
	if t.session != nil {
		t.logUsage(context.Background())
		_ = t.session.Disconnect()
	}
	if t.client != nil {
		_ = t.client.Stop()
	}
}

func (t *Team) sessionOptions() *copilot.CreateSessionOptions {
	largeOutputBytes := int64(256 << 10)
	available := make([]string, 0)
	seen := make(map[string]struct{})
	for _, member := range t.members {
		for _, name := range member.Tools {
			if _, ok := seen[name]; ok {
				continue
			}
			seen[name] = struct{}{}
			available = append(available, name)
		}
	}
	for _, tool := range t.tools {
		if _, ok := seen[tool.Name]; !ok {
			seen[tool.Name] = struct{}{}
			available = append(available, tool.Name)
		}
	}
	slices.Sort(available)

	agents := make([]copilot.CustomAgentConfig, 0, len(t.members))
	for _, name := range []string{plannerName, environmentDetectorName, portInstallerName, portDoctorName, portEditorName, tripletEditorName, baselineUpdaterName} {
		member := t.members[name]
		turns := member.MaxTurns
		agents = append(agents, copilot.CustomAgentConfig{
			Name: member.Name, DisplayName: member.DisplayName, Description: member.Prompt,
			Prompt: member.Prompt, Tools: append([]string(nil), member.Tools...),
			Infer: copilot.Bool(false), MaxToolTurns: &turns,
		})
	}

	options := &copilot.CreateSessionOptions{
		ClientName:            "vcpkg-agents",
		Model:                 t.config.Options.Model,
		WorkingDirectory:      t.config.Workspace,
		EnableConfigDiscovery: copilot.Bool(false),
		Filesystem: copilot.CreateSessionFilesystemOptions{
			TrustWorkingDirectory: copilot.WorkingDirectoryTrustSession,
			AdditionalDirectories: t.additionalDirectories(),
		},
		State: copilot.SessionStateOptions{SkipEmbeddingRetrieval: copilot.Bool(true)},
		Instructions: copilot.CreateSessionInstructionOptions{
			OnDemandDiscovery: copilot.Bool(false), SkipCustomInstructions: copilot.Bool(true),
		},
		Hooks: copilot.SessionHookOptions{
			EnableRepositoryHooks: copilot.Bool(false),
			Handlers: &copilot.SessionHooks{
				OnPreToolUse: t.preToolUse, OnPostToolUse: t.postToolUse,
				OnPostToolUseFailure: t.postToolUseFailure,
			},
		},
		Git: copilot.SessionGitOptions{EnableHostGitOperations: copilot.Bool(false), CoauthorEnabled: copilot.Bool(false)},
		Skills: copilot.SessionSkillOptions{
			Enabled: copilot.Bool(false), IncludedBuiltinSkills: []string{},
		},
		Tools: copilot.SessionToolOptions{Definitions: t.tools, AvailableTools: available,
			LargeOutput: &copilot.LargeToolOutputConfig{
				MaxSizeBytes: &largeOutputBytes, OutputDirectory: t.config.Scratch,
			}},
		Agents: copilot.SessionAgentOptions{
			Definitions: agents, Selected: plannerName, LocalDiscoveryOnly: copilot.Bool(true),
			IncludedBuiltinAgents: []string{},
		},
		Permissions: copilot.SessionPermissionOptions{
			Mode: rpc.PermissionModeManual, OnRequest: t.permission,
			Sandbox: t.sandboxConfig(),
		},
		MCP: copilot.SessionMCPOptions{
			Servers: map[string]copilot.MCPServerConfig{
				microsoftLearnMCPName: copilot.MCPHTTPServerConfig{
					URL: "https://learn.microsoft.com/api/mcp", Tools: []string{"microsoft_docs_search", "microsoft_docs_fetch"},
				},
			},
		},
		SystemMessage: &copilot.SystemMessageConfig{Mode: "append", Content: teamPrompt},
	}
	return options
}

func (t *Team) additionalDirectories() []string {
	var result []string
	for _, member := range t.members {
		result = append(result, member.BaseScope.Read...)
	}
	return uniquePaths(result)
}

func (t *Team) sandboxConfig() *rpc.SandboxConfig {
	enabled := t.config.Options.EnableSandbox
	read := configReadRoots(t.config)
	write := []string{t.config.Scratch, t.config.Roots.Buildtrees, t.config.Roots.Downloads, t.config.Roots.Installed, t.config.Roots.Packages}
	if t.config.allowed("ports") {
		write = append(write, filepath.Join(t.config.Workspace, "ports"))
	}
	if t.config.allowed("versions") {
		write = append(write, filepath.Join(t.config.Workspace, "versions"))
	}
	if t.config.allowed("triplets") || t.config.allowed("overlays") {
		write = append(write, t.config.OverlayTriplets...)
	}
	return &rpc.SandboxConfig{
		Enabled: enabled, AddCurrentWorkingDirectory: copilot.Bool(false),
		AllowDevToolAccess: copilot.Bool(false), AllowTempStorage: copilot.Bool(false), AllowBypass: copilot.Bool(false),
		UserPolicy: &rpc.SandboxConfigUserPolicy{Filesystem: &rpc.SandboxConfigUserPolicyFilesystem{
			ReadonlyPaths: read, ReadwritePaths: uniquePaths(write),
		}},
	}
}

func (t *Team) logUsage(ctx context.Context) {
	if t.session == nil {
		return
	}
	metrics, err := t.session.RPC.Usage.GetMetrics(ctx)
	if err != nil {
		slog.Warn("usage", "error", err)
		return
	}
	credits := 0.0
	if metrics.TotalNanoAiu != nil {
		credits = *metrics.TotalNanoAiu / 1e9
	}
	slog.Info("usage", "session", t.session.SessionID, "ai_credits", credits,
		"premium_requests", metrics.TotalPremiumRequestCost, "user_requests", metrics.TotalUserRequests)
}

func attachSession[T any](value T, session *copilot.Session) T {
	pointer := any(&value)
	if carrier, ok := pointer.(interface{ setSession(*copilot.Session) }); ok {
		carrier.setSession(session)
	}
	return value
}

func (t *Team) runTurn(ctx context.Context, member *Member, prompt string) (any, error) {
	t.turnMu.Lock()
	defer t.turnMu.Unlock()
	if t.session == nil {
		return nil, errors.New("Copilot session has not been created")
	}
	for {
		select {
		case <-member.out:
		default:
			goto drained
		}
	}
drained:
	scope := member.Scope()
	t.active.Store(member)
	defer t.active.Store(nil)
	slog.Info("turn", "agent", member.Name, "goal", truncate(redactText(prompt, t.config.SecretValues), 300))
	turnCtx, cancel := context.WithTimeout(ctx, member.Deadline)
	defer cancel()
	if _, err := t.session.RPC.Agent.Select(turnCtx, &rpc.AgentSelectRequest{Name: member.Name}); err != nil {
		return nil, fmt.Errorf("%s: select agent: %w", member.Name, err)
	}
	turns := member.MaxTurns
	response, err := t.session.SendAndWait(turnCtx, copilot.MessageOptions{
		Prompt: prompt, Source: copilot.MessageSourceAgent(member.Name), MaxToolTurns: &turns,
	})
	if err != nil {
		return nil, fmt.Errorf("%s: model turn: %w", member.Name, err)
	}
	var output any
	select {
	case output = <-member.out:
	default:
		firstReply := assistantText(response)
		recovery := "The previous reply violated the team contract. Do not answer in text. Call exactly one send_* handoff tool now using the payload already supplied."
		response, err = t.session.SendAndWait(turnCtx, copilot.MessageOptions{
			Prompt: recovery, Source: copilot.MessageSourceAgent(member.Name), MaxToolTurns: &turns,
		})
		if err != nil {
			return nil, fmt.Errorf("%s: handoff recovery: %w", member.Name, err)
		}
		select {
		case output = <-member.out:
		default:
			return nil, fmt.Errorf("%s: turn ended without a handoff tool; replies=%q / %q",
				member.Name, truncate(firstReply, 500), truncate(assistantText(response), 500))
		}
	}
	trigger := rpc.SessionHistoryCompactRequestTriggerManual
	compactInstructions := "Keep: scenario, roots, write scopes, per-triplet and per-port state, blockers, and evidence paths. Drop: summarized tool output."
	compactCtx, compactCancel := context.WithTimeout(ctx, 3*time.Minute)
	defer compactCancel()
	_, err = t.session.RPC.History.Compact(compactCtx, &rpc.SessionHistoryCompactRequest{
		Trigger: &trigger, CustomInstructions: &compactInstructions,
	})
	if err != nil {
		return nil, fmt.Errorf("%s: compact history: %w", member.Name, err)
	}
	slog.Debug("handoff", "agent", member.Name, "type", fmt.Sprintf("%T", output), "cwd", scope.CWD)
	return attachOutputSession(output, t.session), nil
}

func assistantText(event *copilot.SessionEvent) string {
	if event == nil {
		return ""
	}
	if message, ok := event.Data.(*copilot.AssistantMessageData); ok && message != nil {
		return redactText(message.Content, collectSecretValues())
	}
	return fmt.Sprintf("%T", event.Data)
}

func attachOutputSession(value any, session *copilot.Session) any {
	switch message := value.(type) {
	case DetectRequest:
		return attachSession(message, session)
	case EnvReport:
		return attachSession(message, session)
	case InstallBatch:
		return attachSession(message, session)
	case InstallFailure:
		return attachSession(message, session)
	case InstallReport:
		return attachSession(message, session)
	case PortGoals:
		return attachSession(message, session)
	case TripletGoals:
		return attachSession(message, session)
	case Blocker:
		return attachSession(message, session)
	case RetryRequest:
		return attachSession(message, session)
	case ReinstallRequest:
		return attachSession(message, session)
	case HostFactsRequest:
		return attachSession(message, session)
	case HostFacts:
		return attachSession(message, session)
	case BaselineRequest:
		return attachSession(message, session)
	case BaselineReport:
		return attachSession(message, session)
	case FinalReport:
		return attachSession(message, session)
	default:
		return value
	}
}

func copyPrompt(tool string, value any) string {
	data, err := json.Marshal(value)
	if err != nil {
		return fmt.Sprintf("Call %s. Serialization error: %v", tool, err)
	}
	return fmt.Sprintf("Call %s exactly once. Copy this payload without inventing or changing fields:\n%s", tool, data)
}

func handoffTool[T any](team *Team, member *Member, name, description string, validate func(T) error) copilot.Tool {
	tool := copilot.DefineTool(name, description, func(payload T, invocation copilot.ToolInvocation) (string, error) {
		if err := team.authorizeActiveTool(member, name, invocation); err != nil {
			return "", err
		}
		if err := validate(payload); err != nil {
			return "", fmt.Errorf("invalid %s handoff: %w", name, err)
		}
		select {
		case member.out <- payload:
			slog.Info("handoff tool", "agent", member.Name, "tool", name)
			return "handoff accepted", nil
		default:
			return "", errors.New("this turn already produced a handoff")
		}
	})
	tool.IsTerminal = true
	return tool
}

func validateGoal(handoff Handoff) error {
	if strings.TrimSpace(handoff.Goal) == "" {
		return errors.New("goal is required")
	}
	if len(handoff.Evidence) == 0 {
		return errors.New("at least one evidence path or fact is required")
	}
	return nil
}

func (t *Team) defineTools() []copilot.Tool {
	tools := []copilot.Tool{
		t.defineVcpkgHelp(), t.defineVcpkgQuery(), t.defineVcpkgInstall(), t.defineVcpkgRemove(),
		t.defineReadLog(), t.defineProbeTool(), t.defineDetectEnvironment(), t.defineDetectCompiler(),
		t.defineGHRead(), t.defineDownloadSHA512(), t.defineVcpkgCreate(),
		t.definePreparePatch(), t.defineMakePatch(), t.defineVersionUpdate(), t.defineGitCommit(),
	}
	tools = append(tools,
		handoffTool(t, t.planner.Member, "send_detect_request", "Send a DetectRequest to Environment Detector.", func(v DetectRequest) error { return validateGoal(v.Handoff) }),
		handoffTool(t, t.planner.Member, "send_install_requests", "Send the ordered InstallRequest batch to Port Installer.", func(v InstallBatch) error {
			if err := validateGoal(v.Handoff); err != nil {
				return err
			}
			if len(v.Requests) == 0 {
				return errors.New("requests cannot be empty")
			}
			return nil
		}),
		handoffTool(t, t.planner.Member, "send_baseline_request", "Send a BaselineRequest to Baseline Updater.", func(v BaselineRequest) error { return validateGoal(v.Handoff) }),
		handoffTool(t, t.planner.Member, "send_final_report", "Send the FinalReport to the caller.", func(v FinalReport) error { return validateGoal(v.Handoff) }),
		handoffTool(t, t.detector.Member, "send_env_report", "Send an EnvReport to Planner.", func(v EnvReport) error { return validateGoal(v.Handoff) }),
		handoffTool(t, t.detector.Member, "send_host_facts", "Send HostFacts to Triplet Editor.", func(v HostFacts) error { return validateGoal(v.Handoff) }),
		handoffTool(t, t.installer.Member, "send_install_failure", "Send an InstallFailure to Port Doctor.", func(v InstallFailure) error { return validateGoal(v.Handoff) }),
		handoffTool(t, t.installer.Member, "send_install_report", "Send an InstallReport to Planner.", func(v InstallReport) error { return validateGoal(v.Handoff) }),
		handoffTool(t, t.doctor.Member, "send_port_goals", "Send PortGoals to Port Editor.", func(v PortGoals) error { return validateGoal(v.Handoff) }),
		handoffTool(t, t.doctor.Member, "send_triplet_goals", "Send TripletGoals to Triplet Editor.", func(v TripletGoals) error { return validateGoal(v.Handoff) }),
		handoffTool(t, t.doctor.Member, "send_blocker", "Send a Blocker to Planner.", func(v Blocker) error { return validateGoal(v.Handoff) }),
		handoffTool(t, t.editor.Member, "send_retry_request", "Send a RetryRequest to Port Installer.", func(v RetryRequest) error {
			if err := validateGoal(v.Handoff); err != nil {
				return err
			}
			if len(v.ChangedFiles) == 0 {
				return errors.New("changedFiles cannot be empty")
			}
			for _, path := range v.ChangedFiles {
				if !insideAny(path, t.editor.Scope().Write) {
					return fmt.Errorf("changed file outside Port Editor scope: %s", path)
				}
			}
			return nil
		}),
		handoffTool(t, t.triplet.Member, "send_reinstall_request", "Send a ReinstallRequest to Planner.", func(v ReinstallRequest) error {
			if err := validateGoal(v.Handoff); err != nil {
				return err
			}
			if !v.Blocked && (v.TripletFile == "" || !insideAny(v.TripletFile, t.triplet.Scope().Write)) {
				return errors.New("triplet file is outside Triplet Editor write scope")
			}
			return nil
		}),
		handoffTool(t, t.triplet.Member, "send_host_facts_request", "Ask Environment Detector for HostFacts.", func(v HostFactsRequest) error { return validateGoal(v.Handoff) }),
		handoffTool(t, t.baseline.Member, "send_baseline_report", "Send a BaselineReport to Planner.", func(v BaselineReport) error { return validateGoal(v.Handoff) }),
	)
	return tools
}

func (t *Team) authorizeActiveTool(member *Member, name string, invocation copilot.ToolInvocation) error {
	active := t.active.Load()
	if active == nil || active != member {
		return fmt.Errorf("%s is not the active member", member.Name)
	}
	if !member.hasTool(name) {
		return fmt.Errorf("%s cannot use %s", member.Name, name)
	}
	if invocation.AgentID != "" && invocation.AgentID != member.Name {
		return fmt.Errorf("tool agent %q does not match active member %q", invocation.AgentID, member.Name)
	}
	return nil
}

func (t *Team) preToolUse(input copilot.PreToolUseHookInput, _ copilot.HookInvocation) (*copilot.PreToolUseHookOutput, error) {
	member := t.active.Load()
	if member == nil {
		return denyHook("no active member"), nil
	}
	scope := member.Scope()
	if input.WorkingDirectory != "" && !insideAny(input.WorkingDirectory, []string{scope.CWD}) {
		return denyHook("working directory outside the active member scope"), nil
	}
	if !member.hasTool(input.ToolName) {
		return denyHook(fmt.Sprintf("%s cannot use %s", member.Name, input.ToolName)), nil
	}
	if isShellTool(input.ToolName) && len(scope.Shell) == 0 {
		return denyHook(member.Name + " has no shell command policy"), nil
	}
	if strings.HasPrefix(input.ToolName, "send_") {
		return &copilot.PreToolUseHookOutput{PermissionDecision: "allow"}, nil
	}
	return &copilot.PreToolUseHookOutput{PermissionDecision: "ask"}, nil
}

func denyHook(reason string) *copilot.PreToolUseHookOutput {
	return &copilot.PreToolUseHookOutput{PermissionDecision: "deny", PermissionDecisionReason: reason}
}

func isShellTool(name string) bool {
	switch strings.ToLower(name) {
	case "bash", "powershell", "pwsh", "shell":
		return true
	default:
		return false
	}
}

func (t *Team) permission(request copilot.PermissionRequest, _ copilot.PermissionInvocation) (rpc.PermissionDecision, error) {
	member := t.active.Load()
	if member == nil {
		return rejectDecision("no active member"), nil
	}
	scope := member.Scope()
	switch request := request.(type) {
	case *rpc.PermissionRequestRead:
		if insideAny(request.Path, scope.Read) {
			return &rpc.PermissionDecisionApproveOnce{}, nil
		}
		return rejectDecision("read outside member scope: " + request.Path), nil
	case *rpc.PermissionRequestWrite:
		if insideAny(request.FileName, scope.Write) {
			slog.Info("write approved", "agent", member.Name, "path", request.FileName)
			return &rpc.PermissionDecisionApproveOnce{}, nil
		}
		return rejectDecision("write outside member scope: " + request.FileName), nil
	case *rpc.PermissionRequestShell:
		if reason := authorizeShell(*request, scope); reason != "" {
			return rejectDecision(reason), nil
		}
		return &rpc.PermissionDecisionApproveOnce{}, nil
	case *rpc.PermissionRequestURL:
		if !allowURL(request.URL, scope.Network) {
			return rejectDecision("URL outside member network scope: " + safeURL(request.URL)), nil
		}
		return &rpc.PermissionDecisionApproveOnce{}, nil
	case *rpc.PermissionRequestMCP:
		if request.ServerName == microsoftLearnMCPName && request.ReadOnly &&
			(member.Name == portDoctorName || member.Name == tripletEditorName) {
			return &rpc.PermissionDecisionApproveOnce{}, nil
		}
		return rejectDecision("MCP request outside member scope"), nil
	case *rpc.PermissionRequestCustomTool:
		if member.hasTool(request.ToolName) {
			return &rpc.PermissionDecisionApproveOnce{}, nil
		}
		return rejectDecision(fmt.Sprintf("%s cannot use %s", member.Name, request.ToolName)), nil
	case rpc.PermissionRequestRead:
		if insideAny(request.Path, scope.Read) {
			return &rpc.PermissionDecisionApproveOnce{}, nil
		}
		return rejectDecision("read outside member scope: " + request.Path), nil
	case rpc.PermissionRequestWrite:
		if insideAny(request.FileName, scope.Write) {
			slog.Info("write approved", "agent", member.Name, "path", request.FileName)
			return &rpc.PermissionDecisionApproveOnce{}, nil
		}
		return rejectDecision("write outside member scope: " + request.FileName), nil
	case rpc.PermissionRequestShell:
		if reason := authorizeShell(request, scope); reason != "" {
			return rejectDecision(reason), nil
		}
		return &rpc.PermissionDecisionApproveOnce{}, nil
	case rpc.PermissionRequestURL:
		if !allowURL(request.URL, scope.Network) {
			return rejectDecision("URL outside member network scope: " + safeURL(request.URL)), nil
		}
		return &rpc.PermissionDecisionApproveOnce{}, nil
	case rpc.PermissionRequestMCP:
		if request.ServerName == microsoftLearnMCPName && request.ReadOnly &&
			(member.Name == portDoctorName || member.Name == tripletEditorName) {
			return &rpc.PermissionDecisionApproveOnce{}, nil
		}
		return rejectDecision("MCP request outside member scope"), nil
	case rpc.PermissionRequestCustomTool:
		if member.hasTool(request.ToolName) {
			return &rpc.PermissionDecisionApproveOnce{}, nil
		}
		return rejectDecision(fmt.Sprintf("%s cannot use %s", member.Name, request.ToolName)), nil
	default:
		return rejectDecision("permission request kind is not allowed"), nil
	}
}

func rejectDecision(reason string) rpc.PermissionDecision {
	return &rpc.PermissionDecisionReject{Feedback: &reason}
}

func authorizeShell(request rpc.PermissionRequestShell, scope Scope) string {
	if len(scope.Shell) == 0 {
		return "member has no shell command policy"
	}
	if request.RequestSandboxBypass != nil && *request.RequestSandboxBypass {
		return "sandbox bypass is forbidden"
	}
	allowedPrograms := make(map[string]bool)
	for _, rule := range scope.Shell {
		allowedPrograms[rule.Program] = true
	}
	if len(request.Commands) == 0 {
		return "shell command parser returned no commands"
	}
	for _, command := range request.Commands {
		name := commandIdentifier(command.Identifier)
		if !allowedPrograms[name] {
			return "shell command is not allowed: " + name
		}
		for _, rule := range scope.Shell {
			if strings.EqualFold(name, rule.Program) && rule.ReadOnly && !command.ReadOnly {
				return "shell command is not read-only: " + name
			}
		}
	}
	if len(request.CommandSegments) == 0 {
		return "shell command segments are unavailable; refusing an ambiguous command"
	}
	for _, segment := range request.CommandSegments {
		words := strings.Fields(segment.FullCommandText)
		if len(words) == 0 {
			return "empty shell command segment"
		}
		if !matchesShellRule(words, scope.Shell) {
			return "shell command arguments are not allowed"
		}
	}
	for _, path := range request.PossiblePaths {
		if !insideAny(path, scope.Read) {
			return "shell path outside member read scope: " + path
		}
		if request.HasWriteFileRedirection && !insideAny(path, scope.Write) {
			return "shell redirection outside member write scope: " + path
		}
	}
	for _, possibleURL := range request.PossibleURLs {
		if !allowURL(possibleURL.URL, scope.Network) {
			return "shell URL outside member network scope"
		}
	}
	return ""
}

func commandIdentifier(command string) string {
	name := filepath.Base(strings.Trim(strings.TrimSpace(command), `"'`))
	return strings.TrimSuffix(strings.ToLower(name), ".exe")
}

func matchesShellRule(words []string, rules []ShellRule) bool {
	program := commandIdentifier(words[0])
	for _, rule := range rules {
		if !strings.EqualFold(program, rule.Program) || len(words) <= len(rule.Prefix) {
			continue
		}
		matched := true
		for index, prefix := range rule.Prefix {
			if !strings.EqualFold(strings.Trim(words[index+1], `"'`), prefix) {
				matched = false
				break
			}
		}
		if matched {
			return true
		}
	}
	return false
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

func (t *Team) postToolUse(input copilot.PostToolUseHookInput, _ copilot.HookInvocation) (*copilot.PostToolUseHookOutput, error) {
	redacted := redactValue(input.ToolResult, t.config.SecretValues)
	if reflectEqual(input.ToolResult, redacted) {
		return nil, nil
	}
	return &copilot.PostToolUseHookOutput{ModifiedResult: redacted}, nil
}

func (t *Team) postToolUseFailure(input copilot.PostToolUseFailureHookInput, _ copilot.HookInvocation) (*copilot.PostToolUseFailureHookOutput, error) {
	errorText := redactText(input.Error, t.config.SecretValues)
	contextText := ""
	if strings.HasPrefix(input.ToolName, "vcpkg_") && (strings.Contains(errorText, "unexpected switch") || strings.Contains(errorText, "unexpected argument")) {
		contextText = "Run vcpkg_help for the same command before retrying. Do not guess the option."
	}
	if contextText == "" {
		return nil, nil
	}
	return &copilot.PostToolUseFailureHookOutput{AdditionalContext: contextText}, nil
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

type vcpkgHelpParams struct {
	Topic string `json:"topic" jsonschema:"vcpkg help topic or command; one word"`
}

type vcpkgQueryParams struct {
	Command string   `json:"command" jsonschema:"version,z-print-config,list,search,depend-info,x-package-info,help"`
	Args    []string `json:"args,omitempty" jsonschema:"arguments after the subcommand"`
}

type vcpkgInstallParams struct {
	Triplet      string   `json:"triplet"`
	Ports        []string `json:"ports,omitempty"`
	Features     []string `json:"features,omitempty"`
	ManifestRoot string   `json:"manifestRoot,omitempty"`
	Stage        string   `json:"stage" jsonschema:"dry-run,only-downloads,build,list,remove"`
	Recurse      bool     `json:"recurse,omitempty"`
}

type readLogParams struct {
	Path   string `json:"path" jsonschema:"absolute log path inside a vcpkg root"`
	Filter string `json:"filter,omitempty" jsonschema:"optional text to match"`
	Tail   int    `json:"tail,omitempty" jsonschema:"last line count; default 200; max 2000"`
}

type probeToolParams struct {
	Tool string   `json:"tool" jsonschema:"registered tool name"`
	Args []string `json:"args,omitempty" jsonschema:"read-only version or path arguments"`
}

type detectEnvironmentParams struct {
	Triplets []string `json:"triplets,omitempty"`
}

type detectCompilerParams struct {
	Triplet string `json:"triplet"`
}

type ghReadParams struct {
	Args []string `json:"args" jsonschema:"read-only gh arguments"`
}

type downloadSHA512Params struct {
	URL string `json:"url" jsonschema:"HTTPS URL"`
}

type vcpkgCreateParams struct {
	Name string `json:"name"`
	URL  string `json:"url"`
	Root string `json:"root,omitempty"`
}

type preparePatchParams struct {
	Port      string `json:"port"`
	SourceDir string `json:"sourceDir"`
}

type makePatchParams struct {
	Port      string `json:"port"`
	Scratch   string `json:"scratch"`
	SourceDir string `json:"sourceDir"`
	Name      string `json:"name"`
	Header    string `json:"header,omitempty"`
}

type versionUpdateParams struct {
	Port  string `json:"port"`
	Stage string `json:"stage" jsonschema:"format or versions"`
}

type gitCommitParams struct {
	Paths   []string `json:"paths"`
	Message string   `json:"message"`
}

func guardedCustomTool[T, U any](team *Team, name, description string, handler func(T, copilot.ToolInvocation) (U, error)) copilot.Tool {
	return copilot.DefineTool(name, description, func(params T, invocation copilot.ToolInvocation) (U, error) {
		active := team.active.Load()
		if active == nil {
			var zero U
			return zero, fmt.Errorf("no active member for %s", name)
		}
		if !active.hasTool(name) {
			var zero U
			return zero, fmt.Errorf("%s cannot use %s", active.Name, name)
		}
		if invocation.AgentID != "" && invocation.AgentID != active.Name {
			var zero U
			return zero, fmt.Errorf("tool agent %q does not match active member %q", invocation.AgentID, active.Name)
		}
		return handler(params, invocation)
	})
}

func (t *Team) defineVcpkgHelp() copilot.Tool {
	return guardedCustomTool(t, "vcpkg_help", "Run vcpkg help for one topic.", func(params vcpkgHelpParams, invocation copilot.ToolInvocation) (string, error) {
		if !wordPattern.MatchString(params.Topic) {
			return "", errors.New("topic must be one word")
		}
		result, err := t.runVcpkg(toolContext(invocation), t.config.Workspace, []string{"help", params.Topic}, 0, false)
		return result.modelText(err), nil
	})
}

func (t *Team) defineVcpkgQuery() copilot.Tool {
	allowed := []string{"version", "z-print-config", "list", "search", "depend-info", "x-package-info", "help"}
	return guardedCustomTool(t, "vcpkg_query", "Run a read-only vcpkg query subcommand.", func(params vcpkgQueryParams, invocation copilot.ToolInvocation) (string, error) {
		if !slices.Contains(allowed, params.Command) {
			return "", fmt.Errorf("%s is not an allowed vcpkg query", params.Command)
		}
		args := append([]string{params.Command}, params.Args...)
		args = append(args, t.commonVcpkgArgs("", false)...)
		result, err := t.runVcpkg(toolContext(invocation), t.config.Workspace, args, 0, false)
		return result.modelText(err), nil
	})
}

func (t *Team) defineVcpkgInstall() copilot.Tool {
	return guardedCustomTool(t, "vcpkg_install", "Run one vcpkg install stage with fixed arguments from Go.", func(params vcpkgInstallParams, invocation copilot.ToolInvocation) (string, error) {
		if !slices.Contains([]string{"dry-run", "only-downloads", "build"}, params.Stage) {
			return "", errors.New("stage must be dry-run, only-downloads, or build")
		}
		request := InstallRequest{
			Triplet: params.Triplet, Ports: params.Ports, Features: params.Features,
			ManifestRoot: params.ManifestRoot, DryRunOnly: params.Stage == "dry-run",
		}
		result, err := t.installStage(toolContext(invocation), request, params.Stage)
		return result.modelText(err), nil
	})
}

func (t *Team) defineVcpkgRemove() copilot.Tool {
	return guardedCustomTool(t, "vcpkg_remove", "Remove requested ports in classic registry mode.", func(params vcpkgInstallParams, invocation copilot.ToolInvocation) (string, error) {
		if t.config.Scenario != "registry" {
			return "", errors.New("vcpkg_remove is forbidden in manifest mode")
		}
		result, err := t.removeStage(toolContext(invocation), InstallRequest{Triplet: params.Triplet, Ports: params.Ports})
		return result.modelText(err), nil
	})
}

func (t *Team) defineReadLog() copilot.Tool {
	return guardedCustomTool(t, "read_log", "Read a bounded tail or matching lines from a vcpkg log.", func(params readLogParams, _ copilot.ToolInvocation) (string, error) {
		roots := []string{t.config.Roots.Buildtrees, t.config.Roots.Downloads, t.config.Roots.Installed, t.config.Roots.Packages, t.config.LogDirectory}
		if !insideAny(params.Path, roots) {
			return "", errors.New("log path is outside the vcpkg roots")
		}
		return t.readLog(params.Path, params.Filter, params.Tail)
	})
}

func (t *Team) defineProbeTool() copilot.Tool {
	allowed := map[string]bool{
		"vcpkg": true, "git": true, "gh": true, "cmake": true, "ninja": true, "pwsh": true, "powershell": true,
		"bash": true, "curl": true, "tar": true, "zip": true, "unzip": true, "python": true, "meson": true,
		"pkg-config": true, "winget": true, "choco": true, "apt-cache": true, "brew": true, "copilot": true,
	}
	return guardedCustomTool(t, "probe_tool", "Run one registered read-only tool probe.", func(params probeToolParams, invocation copilot.ToolInvocation) (string, error) {
		if !allowed[params.Tool] {
			return "", fmt.Errorf("%s is not a registered probe tool", params.Tool)
		}
		path := t.config.Tools[params.Tool]
		if path == "" {
			return "", fmt.Errorf("%s is unavailable", params.Tool)
		}
		args := params.Args
		if len(args) == 0 {
			args = defaultProbeArgs(params.Tool)
		}
		if !readOnlyProbeArgs(params.Tool, args) {
			return "", errors.New("probe arguments are not read-only")
		}
		result, err := t.runCommand(toolContext(invocation), t.config.Workspace, path, args, 30*time.Second, "")
		return result.modelText(err), nil
	})
}

func (t *Team) defineDetectEnvironment() copilot.Tool {
	return guardedCustomTool(t, "detect_environment", "Run the same deterministic environment procedure used by init.", func(params detectEnvironmentParams, _ copilot.ToolInvocation) (string, error) {
		report := t.detectEnvironment(context.Background(), DetectRequest{Triplets: params.Triplets})
		data, err := json.Marshal(report)
		return string(data), err
	})
}

func (t *Team) defineDetectCompiler() copilot.Tool {
	return guardedCustomTool(t, "detect_compiler", "Run vcpkg's detect_compiler through a forced dry-run x-set-installed call.", func(params detectCompilerParams, invocation copilot.ToolInvocation) (string, error) {
		fact, err := t.detectCompiler(toolContext(invocation), params.Triplet)
		data, marshalErr := json.Marshal(fact)
		if err != nil {
			return fmt.Sprintf("error: %v\n%s", err, data), nil
		}
		return string(data), marshalErr
	})
}

func (t *Team) defineGHRead() copilot.Tool {
	return guardedCustomTool(t, "gh_read", "Run one allowlisted read-only gh command.", func(params ghReadParams, invocation copilot.ToolInvocation) (string, error) {
		if !isReadOnlyGH(params.Args) {
			return "", errors.New("gh command is not read-only")
		}
		path := t.config.Tools["gh"]
		if path == "" {
			return "", errors.New("gh is unavailable")
		}
		result, err := t.runCommand(toolContext(invocation), t.config.Workspace, path, params.Args, 2*time.Minute, "")
		return result.modelText(err), nil
	})
}

func (t *Team) defineDownloadSHA512() copilot.Tool {
	return guardedCustomTool(t, "download_sha512", "Download an HTTPS source archive and return SHA512.", func(params downloadSHA512Params, invocation copilot.ToolInvocation) (string, error) {
		if !allowURL(params.URL, []string{"*"}) {
			return "", errors.New("download URL must use HTTPS")
		}
		request, err := http.NewRequestWithContext(toolContext(invocation), http.MethodGet, params.URL, nil)
		if err != nil {
			return "", err
		}
		client := *t.httpClient
		previousRedirect := client.CheckRedirect
		client.CheckRedirect = func(redirect *http.Request, via []*http.Request) error {
			if !allowURL(redirect.URL.String(), []string{"*"}) {
				return fmt.Errorf("download redirect left HTTPS: %s", safeURL(redirect.URL.String()))
			}
			if previousRedirect != nil {
				return previousRedirect(redirect, via)
			}
			return nil
		}
		response, err := client.Do(request)
		if err != nil {
			return "", err
		}
		defer response.Body.Close()
		if response.StatusCode != http.StatusOK {
			return "", fmt.Errorf("download %s: %s", safeURL(params.URL), response.Status)
		}
		hash := sha512.New()
		if _, err := io.Copy(hash, response.Body); err != nil {
			return "", err
		}
		return hex.EncodeToString(hash.Sum(nil)), nil
	})
}

func (t *Team) defineVcpkgCreate() copilot.Tool {
	return guardedCustomTool(t, "vcpkg_create", "Run vcpkg create into a port root in the active Port Editor scope.", func(params vcpkgCreateParams, invocation copilot.ToolInvocation) (string, error) {
		if !portNamePattern.MatchString(params.Name) || !allowURL(params.URL, []string{"*"}) {
			return "", errors.New("invalid port name or source URL")
		}
		root := params.Root
		if root == "" {
			root = filepath.Join(t.config.Workspace, "ports")
		}
		if !insideAny(root, t.editor.Scope().Write) {
			return "", errors.New("port root is outside Port Editor write scope")
		}
		args := []string{"create", params.Name, params.URL, "--x-builtin-ports-root=" + root}
		result, err := t.runVcpkg(toolContext(invocation), root, args, 0, false)
		return result.modelText(err), nil
	})
}

func (t *Team) definePreparePatch() copilot.Tool {
	return guardedCustomTool(t, "prepare_patch", "Copy a .clean source tree to scratch and initialize a baseline git commit.", func(params preparePatchParams, invocation copilot.ToolInvocation) (string, error) {
		active := t.active.Load()
		if active == nil {
			return "", errors.New("no active member")
		}
		if !insideAny(params.SourceDir, []string{t.config.Roots.Buildtrees}) {
			return "", errors.New("source must be inside buildtrees")
		}
		scratch := filepath.Join(t.config.Scratch, "patches", sanitizeName(params.Port)+"-"+strconv.FormatUint(t.commandSeq.Add(1), 10))
		if err := copyTree(params.SourceDir, scratch); err != nil {
			return "", err
		}
		if _, err := t.runGit(toolContext(invocation), scratch, "-c", "core.autocrlf=false", "init"); err != nil {
			return "", err
		}
		if _, err := t.runGit(toolContext(invocation), scratch, "-c", "core.autocrlf=false", "add", "-A"); err != nil {
			return "", err
		}
		if _, err := t.runGit(toolContext(invocation), scratch, "-c", "core.autocrlf=false", "-c", "user.name=vcpkg-agents", "-c", "user.email=vcpkg-agents@localhost", "commit", "-m", "Baseline"); err != nil {
			return "", err
		}
		return scratch, nil
	})
}

func (t *Team) defineMakePatch() copilot.Tool {
	return guardedCustomTool(t, "make_patch", "Create a patch from an edited scratch tree, verify it on a fresh clean copy, and delete scratch.", func(params makePatchParams, invocation copilot.ToolInvocation) (string, error) {
		if !insideAny(params.Scratch, []string{filepath.Join(t.config.Scratch, "patches")}) {
			return "", errors.New("scratch is outside the team scratch folder")
		}
		if !insideAny(params.SourceDir, []string{t.config.Roots.Buildtrees}) {
			return "", errors.New("clean source is outside buildtrees")
		}
		name := sanitizePatchName(params.Name)
		portRoot := resolvePortRoot(t.config, params.Port)
		patchPath := filepath.Join(portRoot, name+".patch")
		if !insideAny(patchPath, t.editor.Scope().Write) {
			return "", errors.New("patch destination is outside Port Editor write scope")
		}
		defer os.RemoveAll(params.Scratch)
		output, err := t.runGit(toolContext(invocation), params.Scratch, "-c", "core.autocrlf=false", "diff", "--output="+patchPath)
		if err != nil {
			return output, err
		}
		if params.Header != "" {
			patch, err := os.ReadFile(patchPath)
			if err != nil {
				return "", err
			}
			header := "# " + strings.TrimSpace(strings.ReplaceAll(params.Header, "\n", " ")) + "\n\n"
			if err := os.WriteFile(patchPath, append([]byte(header), patch...), 0o644); err != nil {
				return "", err
			}
		}
		verify := filepath.Join(t.config.Scratch, "verify-"+sanitizeName(params.Port)+"-"+strconv.FormatUint(t.commandSeq.Add(1), 10))
		defer os.RemoveAll(verify)
		if err := copyTree(params.SourceDir, verify); err != nil {
			return "", err
		}
		if _, err := t.runGit(toolContext(invocation), verify, "init"); err != nil {
			return "", err
		}
		verifyArgs := []string{"-c", "core.longpaths=true", "-c", "core.autocrlf=false", "-c", "core.filemode=true",
			"--work-tree=.", "--git-dir=.git", "apply", patchPath, "--ignore-whitespace", "--whitespace=nowarn", "--verbose"}
		applyOutput, err := t.runGit(toolContext(invocation), verify, verifyArgs...)
		if err != nil {
			return applyOutput, err
		}
		return patchPath, nil
	})
}

func (t *Team) defineVersionUpdate() copilot.Tool {
	return guardedCustomTool(t, "version_update", "Format one port manifest and update that port's registry version files.", func(params versionUpdateParams, invocation copilot.ToolInvocation) (string, error) {
		if t.config.Scenario != "registry" || !portNamePattern.MatchString(params.Port) {
			return "", errors.New("version_update is registry-only and needs one valid port name")
		}
		portRoot := filepath.Join(t.config.Workspace, "ports", params.Port)
		manifest := filepath.Join(portRoot, "vcpkg.json")
		if !insideAny(manifest, t.baseline.Scope().Write) {
			return "", errors.New("port manifest is outside Baseline Updater write scope")
		}
		switch params.Stage {
		case "format":
			formatArgs := append([]string{"format-manifest", manifest}, t.commonVcpkgArgs("", false)...)
			format, err := t.runVcpkg(toolContext(invocation), t.config.Workspace, formatArgs, 0, false)
			return format.modelText(err), nil
		case "versions":
			// Continue below. The first commit must exist so x-add-version hashes HEAD's port tree.
		default:
			return "", errors.New("stage must be format or versions")
		}
		if output, err := t.runGit(toolContext(invocation), t.config.Workspace, "diff", "--quiet", "--", filepath.Join("ports", params.Port)); err != nil {
			return output, fmt.Errorf("target port has uncommitted changes: %w", err)
		}
		recordPath := versionRecordPath(t.config.Workspace, params.Port)
		createdRecord := false
		if !fileExists(recordPath) {
			if !insideAny(recordPath, t.baseline.Scope().Write) {
				return "", errors.New("version record is outside Baseline Updater write scope")
			}
			if err := os.MkdirAll(filepath.Dir(recordPath), 0o755); err != nil {
				return "", err
			}
			if err := os.WriteFile(recordPath, []byte("{\n  \"versions\": []\n}\n"), 0o644); err != nil {
				return "", err
			}
			createdRecord = true
		}
		args := append([]string{"x-add-version", params.Port,
			"--x-builtin-ports-root=" + filepath.Join(t.config.Workspace, "ports"),
			"--x-builtin-registry-versions-dir=" + filepath.Join(t.config.Workspace, "versions")},
			withoutOverlayArgs(t.commonVcpkgArgs("", false))...)
		if createdRecord {
			args = append(args, "--overwrite-version")
		}
		versionEnvironment := withoutEnvironmentNames(t.config.VcpkgEnv, "VCPKG_OVERLAY_PORTS", "VCPKG_OVERLAY_TRIPLETS")
		update, err := t.runVcpkgEnvironment(toolContext(invocation), t.config.Workspace, args, 0, false, versionEnvironment)
		if err != nil || update.Err != nil {
			if createdRecord {
				_ = os.Remove(recordPath)
			}
			return update.modelText(err), nil
		}
		if err := t.verifyVersionTree(toolContext(invocation), params.Port); err != nil {
			return "", err
		}
		return update.modelText(nil), nil
	})
}

func withoutOverlayArgs(args []string) []string {
	result := make([]string, 0, len(args))
	for _, arg := range args {
		if strings.HasPrefix(arg, "--overlay-ports=") || strings.HasPrefix(arg, "--overlay-triplets=") {
			continue
		}
		result = append(result, arg)
	}
	return result
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

func versionRecordPath(workspace, port string) string {
	return filepath.Join(workspace, "versions", strings.ToLower(port[:1])+"-", port+".json")
}

func (t *Team) verifyVersionTree(ctx context.Context, port string) error {
	tree, err := t.runGit(ctx, t.config.Workspace, "rev-parse", "HEAD:"+filepath.ToSlash(filepath.Join("ports", port)))
	if err != nil {
		return fmt.Errorf("read committed port tree: %w: %s", err, tree)
	}
	recordPath := versionRecordPath(t.config.Workspace, port)
	data, err := os.ReadFile(recordPath)
	if err != nil {
		return fmt.Errorf("read version record: %w", err)
	}
	var record struct {
		Versions []struct {
			GitTree string `json:"git-tree"`
		} `json:"versions"`
	}
	if err := json.Unmarshal(data, &record); err != nil {
		return fmt.Errorf("parse version record: %w", err)
	}
	tree = strings.TrimSpace(tree)
	var recorded []string
	for _, version := range record.Versions {
		recorded = append(recorded, version.GitTree)
		if version.GitTree == tree {
			return nil
		}
	}
	return fmt.Errorf("version record %s does not contain git-tree %s from the port commit (recorded: %s)",
		recordPath, tree, strings.Join(recorded, ","))
}

func (t *Team) defineGitCommit() copilot.Tool {
	return guardedCustomTool(t, "git_commit", "Commit only paths in the active Baseline Updater scope, with the required trailer.", func(params gitCommitParams, invocation copilot.ToolInvocation) (string, error) {
		if len(params.Paths) == 0 || strings.TrimSpace(params.Message) == "" {
			return "", errors.New("paths and message are required")
		}
		scope := t.baseline.Scope()
		absolutePaths := make([]string, 0, len(params.Paths))
		for _, path := range params.Paths {
			absolute := path
			if !filepath.IsAbs(absolute) {
				absolute = filepath.Join(t.config.Workspace, path)
			}
			if !insideAny(absolute, scope.Write) {
				return "", fmt.Errorf("commit path outside scope: %s", path)
			}
			absolutePaths = append(absolutePaths, absolute)
		}
		for _, dirty := range t.config.InitialDirty {
			if insideAny(dirty, absolutePaths) {
				return "", fmt.Errorf("commit path contains a change that existed before this run: %s", dirty)
			}
		}
		staged, err := t.runGit(toolContext(invocation), t.config.Workspace, "diff", "--cached", "--name-only")
		if err != nil {
			return staged, err
		}
		if strings.TrimSpace(staged) != "" {
			return "", errors.New("git index already contains staged changes; Baseline Updater will not include user work")
		}
		gitArgs := []string{"add", "--"}
		gitArgs = append(gitArgs, params.Paths...)
		if output, err := t.runGit(toolContext(invocation), t.config.Workspace, gitArgs...); err != nil {
			return output, err
		}
		staged, err = t.runGit(toolContext(invocation), t.config.Workspace, "diff", "--cached", "--name-only")
		if err != nil {
			return staged, err
		}
		for _, stagedPath := range strings.Split(strings.TrimSpace(staged), "\n") {
			if stagedPath == "" {
				continue
			}
			absolute := filepath.Join(t.config.Workspace, filepath.FromSlash(stagedPath))
			if !insideAny(absolute, absolutePaths) {
				resetArgs := append([]string{"reset", "--"}, params.Paths...)
				_, _ = t.runGit(toolContext(invocation), t.config.Workspace, resetArgs...)
				return "", fmt.Errorf("git index contains a path outside this commit: %s", stagedPath)
			}
		}
		message := strings.TrimSpace(params.Message)
		if !strings.Contains(message, coauthorTrailer) {
			message += "\n\n" + coauthorTrailer
		}
		commitOutput, err := t.runGit(toolContext(invocation), t.config.Workspace, "commit", "-m", message)
		if err != nil {
			resetArgs := append([]string{"reset", "--"}, params.Paths...)
			_, _ = t.runGit(toolContext(invocation), t.config.Workspace, resetArgs...)
			return commitOutput, err
		}
		hashOutput, err := t.runGit(toolContext(invocation), t.config.Workspace, "rev-parse", "HEAD")
		if err != nil {
			return hashOutput, err
		}
		return strings.TrimSpace(hashOutput) + "\n" + commitOutput, nil
	})
}

var (
	wordPattern       = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_-]*$`)
	portNamePattern   = regexp.MustCompile(`^[a-z0-9][a-z0-9+_.-]*$`)
	portMention       = regexp.MustCompile(`(?i)[a-z0-9][a-z0-9+_.-]*(?:\[[a-z0-9+_.-]+(?:,[a-z0-9+_.-]+)*\])?`)
	commitHashPattern = regexp.MustCompile(`^[0-9a-fA-F]{7,40}$`)
)

func defaultProbeArgs(tool string) []string {
	switch strings.ToLower(tool) {
	case "gh", "vcpkg", "copilot", "cmake", "ninja", "python":
		return []string{"--version"}
	case "pwsh", "powershell":
		return []string{"-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"}
	case "bash":
		return []string{"--version"}
	case "winget":
		return []string{"--version"}
	default:
		return []string{"--version"}
	}
}

func readOnlyProbeArgs(tool string, args []string) bool {
	return slices.Equal(args, defaultProbeArgs(tool))
}

var ghReadPrefixes = [][]string{
	{"api", "--method", "GET"}, {"api", "-X", "GET"}, {"api"},
	{"search", "issues"}, {"search", "prs"}, {"search", "code"},
	{"issue", "view"}, {"pr", "view"}, {"pr", "diff"},
	{"release", "list"}, {"release", "view"}, {"auth", "status"},
}

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

func toolContext(invocation copilot.ToolInvocation) context.Context {
	if invocation.TraceContext != nil {
		return invocation.TraceContext
	}
	return context.Background()
}

type CommandResult struct {
	Command  string
	ExitCode int
	Duration time.Duration
	LogPath  string
	Summary  string
	Err      error
}

func (result CommandResult) modelText(startupErr error) string {
	err := result.Err
	if startupErr != nil {
		err = startupErr
	}
	return truncate(fmt.Sprintf("error: %v\nexit=%d\nduration=%s\ncommand=%s\nlog=%s\n%s",
		err, result.ExitCode, result.Duration.Round(time.Millisecond), result.Command, result.LogPath, result.Summary), maxCommandSummary)
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

func (t *Team) runVcpkg(ctx context.Context, cwd string, args []string, timeout time.Duration, lock bool) (CommandResult, error) {
	return t.runVcpkgEnvironment(ctx, cwd, args, timeout, lock, t.config.VcpkgEnv)
}

func (t *Team) runVcpkgEnvironment(ctx context.Context, cwd string, args []string, timeout time.Duration, lock bool, environment []string) (CommandResult, error) {
	t.vcpkgMu.Lock()
	defer t.vcpkgMu.Unlock()
	args = append([]string(nil), args...)
	if lock {
		args = append(args, "--x-wait-for-lock")
	}
	return t.runCommandEnvironment(ctx, cwd, t.config.Tools["vcpkg"], args, timeout, t.config.LogDirectory, environment)
}

func (t *Team) runCommand(ctx context.Context, cwd, executable string, args []string, timeout time.Duration, logDirectory string) (CommandResult, error) {
	return t.runCommandEnvironment(ctx, cwd, executable, args, timeout, logDirectory, nil)
}

func (t *Team) runCommandEnvironment(ctx context.Context, cwd, executable string, args []string, timeout time.Duration, logDirectory string, environment []string) (CommandResult, error) {
	if executable == "" {
		return CommandResult{}, errors.New("executable path is empty")
	}
	if timeout <= 0 {
		timeout = commandTimeout
	}
	commandCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	if cwd == "" {
		cwd = t.config.Workspace
	}
	if logDirectory == "" {
		logDirectory = t.config.LogDirectory
	}
	if err := os.MkdirAll(logDirectory, 0o700); err != nil {
		return CommandResult{}, err
	}
	sequence := t.commandSeq.Add(1)
	logPath := filepath.Join(logDirectory, fmt.Sprintf("command-%06d.log", sequence))
	file, err := os.OpenFile(logPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o600)
	if err != nil {
		return CommandResult{}, err
	}
	writer := &safeLogWriter{file: file, secrets: t.config.SecretValues}
	command := exec.CommandContext(commandCtx, executable, args...)
	command.Dir = cwd
	command.Env = os.Environ()
	if commandIdentifier(executable) == "vcpkg" {
		command.Env = environment
		if command.Env == nil {
			command.Env = t.config.VcpkgEnv
		}
	}
	command.Stdout = writer
	command.Stderr = writer
	started := time.Now()
	err = command.Start()
	result := CommandResult{
		Command: quotedCommand(executable, args), LogPath: logPath, ExitCode: -1,
	}
	if err != nil {
		_ = writer.Close()
		return result, err
	}
	waitErr := make(chan error, 1)
	go func() { waitErr <- command.Wait() }()

	if filepath.Base(executable) == "vcpkg.exe" || filepath.Base(executable) == "vcpkg" {
		if slices.Contains(args, "--x-wait-for-lock") {
			waitErr = t.watchLock(command, waitErr, commandCtx, logPath)
		}
	}
	err = <-waitErr
	_ = writer.Close()
	result.Duration = time.Since(started)
	if command.ProcessState != nil {
		result.ExitCode = command.ProcessState.ExitCode()
	}
	result.Err = err
	result.Summary, _ = summarizeLog(logPath)
	if commandCtx.Err() != nil && err != nil {
		result.Err = fmt.Errorf("%w: %v", commandCtx.Err(), err)
	}
	return result, nil
}

func (t *Team) watchLock(command *exec.Cmd, processDone chan error, ctx context.Context, logPath string) chan error {
	done := make(chan error, 1)
	go func() {
		ticker := time.NewTicker(250 * time.Millisecond)
		defer ticker.Stop()
		var waitingSince time.Time
		lastOffset := int64(0)
		for {
			select {
			case err := <-processDone:
				done <- err
				return
			case <-ctx.Done():
				_ = command.Process.Kill()
				done <- ctx.Err()
				return
			case <-ticker.C:
				data, _ := os.ReadFile(logPath)
				if int64(len(data)) > lastOffset {
					added := string(data[lastOffset:])
					lastOffset = int64(len(data))
					if waitingSince.IsZero() && strings.Contains(added, "waiting to take filesystem lock") {
						waitingSince = time.Now()
					} else if !waitingSince.IsZero() && strings.TrimSpace(added) != "" && !strings.Contains(added, "waiting to take filesystem lock") {
						waitingSince = time.Time{}
					}
				}
				if !waitingSince.IsZero() && time.Since(waitingSince) > t.config.Options.LockWait {
					_ = command.Process.Kill()
					<-processDone
					done <- fmt.Errorf("vcpkg lock wait exceeded %s", t.config.Options.LockWait)
					return
				}
			}
		}
	}()
	return done
}

func quotedCommand(executable string, args []string) string {
	parts := append([]string{strconv.Quote(executable)}, args...)
	return strings.Join(parts, " ")
}

func summarizeLog(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64<<10), 2<<20)
	var matches, tail []string
	for scanner.Scan() {
		line := scanner.Text()
		tail = append(tail, line)
		lower := strings.ToLower(line)
		if strings.Contains(lower, "error:") || strings.Contains(lower, "warning:") ||
			strings.Contains(lower, "result") || strings.Contains(lower, "building ") ||
			strings.Contains(lower, "plan") || strings.Contains(lower, "info:") ||
			strings.Contains(lower, "waiting to take") {
			matches = append(matches, line)
		}
	}
	lines := append(matches, tail...)
	if len(lines) > 240 {
		lines = lines[len(lines)-240:]
	}
	return truncate(strings.Join(lines, "\n"), maxCommandSummary), scanner.Err()
}

func (t *Team) readLog(path, filter string, tail int) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	lines := strings.Split(strings.ReplaceAll(string(data), "\r\n", "\n"), "\n")
	if filter != "" {
		var filtered []string
		lower := strings.ToLower(filter)
		for _, line := range lines {
			if strings.Contains(strings.ToLower(line), lower) {
				filtered = append(filtered, line)
			}
		}
		lines = filtered
	}
	if tail <= 0 {
		tail = 200
	}
	if tail > 2000 {
		tail = 2000
	}
	if len(lines) > tail {
		lines = lines[len(lines)-tail:]
	}
	return truncate(strings.Join(lines, "\n"), maxModelLogBytes), nil
}

func truncate(text string, limit int) string {
	if len(text) <= limit {
		return text
	}
	return text[:limit] + "\n... truncated ..."
}

func (t *Team) runGit(ctx context.Context, cwd string, args ...string) (string, error) {
	result, err := t.runCommand(ctx, cwd, t.config.Tools["git"], args, 5*time.Minute, t.config.LogDirectory)
	data, readErr := os.ReadFile(result.LogPath)
	if readErr == nil {
		result.Summary = string(data)
	}
	return strings.TrimSpace(result.Summary), errors.Join(err, result.Err)
}

func (t *Team) commonVcpkgArgs(triplet string, classic bool) []string {
	args := []string{"--disable-metrics"}
	if t.config.Roots.Vcpkg != "" {
		args = append(args, "--vcpkg-root="+t.config.Roots.Vcpkg)
	}
	if t.config.Roots.Buildtrees != "" {
		args = append(args, "--x-buildtrees-root="+t.config.Roots.Buildtrees)
	}
	if t.config.Roots.Packages != "" {
		args = append(args, "--x-packages-root="+t.config.Roots.Packages)
	}
	if t.config.Roots.Installed != "" {
		args = append(args, "--x-install-root="+t.config.Roots.Installed)
	}
	if t.config.Roots.Downloads != "" {
		args = append(args, "--downloads-root="+t.config.Roots.Downloads)
	}
	for _, overlay := range t.config.OverlayPorts {
		args = append(args, "--overlay-ports="+overlay)
	}
	for _, overlay := range t.config.OverlayTriplets {
		args = append(args, "--overlay-triplets="+overlay)
	}
	if triplet != "" {
		args = append(args, "--triplet="+triplet)
	}
	if t.config.HostTriplet != "" {
		args = append(args, "--host-triplet="+t.config.HostTriplet)
	}
	if classic {
		args = append(args, "--classic")
	}
	return args
}

func (t *Team) installArgs(request InstallRequest, stage string) []string {
	args := []string{"install"}
	args = append(args, t.commonVcpkgArgs(request.Triplet, t.config.Scenario == "registry")...)
	manifestRoot := request.ManifestRoot
	if manifestRoot == "" {
		manifestRoot = t.config.ManifestRoot
	}
	if t.config.Scenario == "manifest" && manifestRoot != "" {
		args = append(args, "--x-manifest-root="+manifestRoot)
		for _, feature := range request.Features {
			args = append(args, "--x-feature="+feature)
		}
	} else {
		args = append(args, request.Ports...)
	}
	switch stage {
	case "dry-run":
		args = append(args, "--dry-run")
	case "only-downloads":
		args = append(args, "--only-downloads")
	}
	return args
}

func (t *Team) installStage(ctx context.Context, request InstallRequest, stage string) (CommandResult, error) {
	args := t.installArgs(request, stage)
	timeout := 10 * time.Minute
	if stage == "build" {
		timeout = installTimeout
	}
	return t.runVcpkg(ctx, request.ManifestRootIfPresent(t.config), args, timeout, true)
}

func (r InstallRequest) ManifestRootIfPresent(config *RuntimeConfig) string {
	if config.Scenario == "manifest" && config.ManifestRoot != "" {
		return config.ManifestRoot
	}
	return config.Workspace
}

func (t *Team) removeStage(ctx context.Context, request InstallRequest) (CommandResult, error) {
	args := []string{"remove", "--recurse"}
	args = append(args, t.commonVcpkgArgs(request.Triplet, true)...)
	args = append(args, request.Ports...)
	return t.runVcpkg(ctx, t.config.Workspace, args, 10*time.Minute, true)
}

func (t *Team) listStage(ctx context.Context, request InstallRequest) (CommandResult, error) {
	args := []string{"list"}
	args = append(args, t.commonVcpkgArgs(request.Triplet, t.config.Scenario == "registry")...)
	if t.config.Scenario == "manifest" && request.ManifestRoot != "" {
		args = append(args, "--x-manifest-root="+request.ManifestRoot)
	}
	return t.runVcpkg(ctx, request.ManifestRootIfPresent(t.config), args, 2*time.Minute, false)
}

func (t *Team) performInstall(ctx context.Context, request InstallRequest) (InstallFailure, SpecResult, bool) {
	var result SpecResult
	result.Triplet = request.Triplet
	result.Spec = strings.Join(request.Ports, ",")
	if result.Spec == "" {
		result.Spec = "manifest"
	}

	list, listErr := t.listStage(ctx, request)
	_ = listErr
	result.Evidence = append(result.Evidence, list.LogPath)
	if t.config.Scenario == "registry" && !request.DryRunOnly && anyPortInstalled(list.Summary, request.Ports) {
		removed, err := t.removeStage(ctx, request)
		if err != nil || removed.Err != nil {
			return t.installFailure(request, "remove", removed, "REMOVE_FAILED"), result, false
		}
		result.Evidence = append(result.Evidence, removed.LogPath)
	}
	dry, err := t.installStage(ctx, request, "dry-run")
	result.Evidence = append(result.Evidence, dry.LogPath)
	if err != nil || dry.Err != nil {
		return t.installFailure(request, "dry-run", dry, vcpkgResultCode(dry.Summary, dry.Err)), result, false
	}
	if request.DryRunOnly {
		result.Stage = "dry-run"
		result.Installed = true
		return InstallFailure{}, result, true
	}
	downloads, err := t.installStage(ctx, request, "only-downloads")
	result.Evidence = append(result.Evidence, downloads.LogPath)
	if err != nil || downloads.Err != nil {
		return t.installFailure(request, "only-downloads", downloads, vcpkgResultCode(downloads.Summary, downloads.Err)), result, false
	}
	build, err := t.installStage(ctx, request, "build")
	result.Evidence = append(result.Evidence, build.LogPath)
	if err != nil || build.Err != nil {
		return t.installFailure(request, "build", build, vcpkgResultCode(build.Summary, build.Err)), result, false
	}
	result.Stage = "build"
	result.Installed = true
	return InstallFailure{}, result, true
}

func anyPortInstalled(summary string, ports []string) bool {
	lower := strings.ToLower(summary)
	for _, port := range ports {
		name := basePortName(port)
		if strings.Contains(lower, strings.ToLower(name)+":") || strings.Contains(lower, strings.ToLower(name)+"[") {
			return true
		}
	}
	return false
}

func (t *Team) installFailure(request InstallRequest, stage string, result CommandResult, code string) InstallFailure {
	spec := strings.Join(request.Ports, ",")
	if spec == "" {
		spec = "manifest"
	}
	return InstallFailure{
		Handoff: Handoff{Goal: "Diagnose this failed vcpkg install and route one repair goal or blocker.",
			Evidence: uniqueStrings(append([]string{result.LogPath}, evidencePaths(t.config, spec, request.Triplet)...))},
		Spec: spec, Triplet: request.Triplet, Stage: stage, ExitCode: result.ExitCode, ResultCode: code,
		Command: result.Command, ErrorLogs: errorLogPaths(t.config, spec, request.Triplet),
		IssueBody: issueBodyPath(t.config), OutputLog: result.LogPath, Scenario: t.config.Scenario,
		ManifestRoot: request.ManifestRoot, Features: request.Features,
	}
}

func evidencePaths(config *RuntimeConfig, spec, triplet string) []string {
	paths := errorLogPaths(config, spec, triplet)
	issue := issueBodyPath(config)
	if issue != "" {
		paths = append(paths, issue)
	}
	return paths
}

func errorLogPaths(config *RuntimeConfig, spec, triplet string) []string {
	name := basePortName(spec)
	pattern := filepath.Join(config.Roots.Buildtrees, name, "error-logs-"+triplet+".txt")
	paths, _ := filepath.Glob(pattern)
	return paths
}

func issueBodyPath(config *RuntimeConfig) string {
	path := filepath.Join(config.Roots.Installed, "vcpkg", "issue_body.md")
	if fileExists(path) {
		return path
	}
	return ""
}

func vcpkgResultCode(summary string, err error) string {
	lower := strings.ToLower(summary)
	switch {
	case strings.Contains(lower, "build_failed"):
		return "BUILD_FAILED"
	case strings.Contains(lower, "patch_failed") || strings.Contains(lower, "applying patch") || strings.Contains(lower, "patch"):
		return "PATCH_FAILED"
	case strings.Contains(lower, "hash") && strings.Contains(lower, "mismatch"):
		return "HASH_MISMATCH"
	case strings.Contains(lower, "compiler"):
		return "COMPILER_FAILED"
	case strings.Contains(lower, "download"):
		return "DOWNLOAD_FAILED"
	case strings.Contains(lower, "version") && strings.Contains(lower, "conflict"):
		return "VERSION_CONFLICT"
	case err != nil:
		return "COMMAND_FAILED"
	default:
		return "UNKNOWN"
	}
}

func basePortName(spec string) string {
	spec = strings.TrimSpace(spec)
	if index := strings.IndexAny(spec, "[:"); index >= 0 {
		spec = spec[:index]
	}
	return spec
}

func (t *Team) detectCompiler(ctx context.Context, triplet string) (TripletFile, error) {
	if !wordPattern.MatchString(triplet) {
		return TripletFile{}, errors.New("invalid triplet name")
	}
	fact := TripletFile{Name: triplet, Path: resolveTripletPath(t.config, triplet), Source: resolveTripletSource(t.config, triplet)}
	args := []string{"x-set-installed", "vcpkg-cmake:" + triplet, "--dry-run"}
	args = append(args, t.commonVcpkgArgs(triplet, false)...)
	args = append(args, "--x-wait-for-lock")
	result, err := t.runVcpkg(ctx, t.config.Workspace, args, 10*time.Minute, false)
	if err != nil || result.Err != nil {
		fact.Error = result.modelText(err)
		fact.Supported = false
		return fact, errors.Join(err, result.Err)
	}
	fact.Supported = true
	return fact, nil
}

func resolveTripletPath(config *RuntimeConfig, triplet string) string {
	name := triplet + ".cmake"
	roots := append([]string(nil), config.OverlayTriplets...)
	roots = append(roots, filepath.Join(config.Roots.Vcpkg, "triplets"), filepath.Join(config.Roots.Vcpkg, "triplets", "community"))
	for _, root := range roots {
		path := filepath.Join(root, name)
		if fileExists(path) {
			return path
		}
	}
	return ""
}

func resolveTripletSource(config *RuntimeConfig, triplet string) string {
	path := resolveTripletPath(config, triplet)
	for _, root := range config.OverlayTriplets {
		if insideAny(path, []string{root}) {
			return "overlay"
		}
	}
	if strings.Contains(path, filepath.Join("triplets", "community")) {
		return "community"
	}
	if path != "" {
		return "builtin"
	}
	return "not-found"
}

func resolvePortRoot(config *RuntimeConfig, port string) string {
	roots := append([]string(nil), config.OverlayPorts...)
	roots = append(roots, filepath.Join(config.Roots.Vcpkg, "ports"))
	for _, root := range roots {
		path := filepath.Join(root, port)
		if isDir(path) {
			return path
		}
	}
	if config.allowed("ports") && config.Scenario == "registry" {
		return filepath.Join(config.Workspace, "ports", port)
	}
	return ""
}

func (t *Team) detectEnvironment(ctx context.Context, request DetectRequest) EnvReport {
	report := EnvReport{
		Handoff: Handoff{
			Goal:     "Build ordered install requests from this verified environment evidence.",
			Evidence: uniqueStrings(append([]string{t.config.Roots.Vcpkg}, t.config.ScenarioEvidence...)),
		},
		Scenario: t.config.Scenario, ScenarioEvidence: t.config.ScenarioEvidence, Roots: t.config.Roots,
		OverlayPorts: t.config.OverlayPorts, OverlayTriplets: t.config.OverlayTriplets, Variables: t.config.Variables,
		HostOS: runtime.GOOS, HostArch: runtime.GOARCH, Warnings: t.config.Warnings, Blockers: t.config.Blockers,
		PortsHint: mentionedPorts(t.config, t.planner.userPrompt), DryRunOnly: isDryRunPrompt(t.planner.userPrompt),
	}
	triplets := request.Triplets
	if len(triplets) == 0 && t.config.DefaultTriplet != "" {
		triplets = []string{t.config.DefaultTriplet}
	}
	for _, triplet := range uniqueStrings(triplets) {
		fact, err := t.detectCompiler(ctx, triplet)
		report.Triplets = append(report.Triplets, fact)
		if err != nil && fact.Path != "" {
			report.Blockers = append(report.Blockers, fmt.Sprintf("%s: compiler detection failed: %s", triplet, fact.Error))
		}
	}
	for _, name := range sortedKeys(t.config.Tools) {
		path := t.config.Tools[name]
		info := ToolInfo{Name: name, Path: path}
		if name == "copilot" || name == "vcpkg" || name == "git" || name == "gh" || name == "cmake" || name == "ninja" || name == "pwsh" || name == "powershell" {
			result, runErr := t.runCommand(ctx, t.config.Workspace, path, defaultProbeArgs(name), 30*time.Second, t.config.LogDirectory)
			info.Version = firstLine(result.Summary)
			if runErr != nil || result.Err != nil {
				info.Error = fmt.Sprintf("%v", errors.Join(runErr, result.Err))
			}
		}
		report.Tools = append(report.Tools, info)
	}
	for _, root := range []string{t.config.Roots.Buildtrees, t.config.Roots.Downloads, t.config.Roots.Installed, t.config.Roots.Packages} {
		if root != "" {
			if ok, _ := writableFolder(root); ok {
				report.Writable = append(report.Writable, root)
			}
		}
	}
	if t.config.Tools["gh"] != "" {
		result, _ := t.runCommand(ctx, t.config.Workspace, t.config.Tools["gh"], []string{"api", "rate_limit"}, 30*time.Second, t.config.LogDirectory)
		report.Web = result.Err == nil
	}
	report.Warnings = uniqueStrings(report.Warnings)
	report.Blockers = uniqueStrings(report.Blockers)
	return report
}

func sortedKeys(values map[string]string) []string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	slices.Sort(keys)
	return keys
}

func firstLine(value string) string {
	value = strings.TrimSpace(value)
	if index := strings.IndexByte(value, '\n'); index >= 0 {
		value = value[:index]
	}
	return truncate(value, 512)
}

func mentionedPorts(config *RuntimeConfig, prompt string) []string {
	var result []string
	ignored := map[string]bool{
		"dry": true, "run": true, "and": true, "for": true, "install": true, "verify": true, "update": true,
		"port": true, "ports": true, "triplet": true, "feature": true, "features": true, "latest": true,
		"windows": true, "linux": true, "android": true, "osx": true, "macos": true, "arm64": true, "x64": true, "x86": true,
	}
	for _, match := range portMention.FindAllString(prompt, -1) {
		spec := strings.TrimSpace(strings.ToLower(match))
		name := basePortName(spec)
		if ignored[name] {
			continue
		}
		for _, overlay := range config.OverlayPorts {
			if fileExists(filepath.Join(overlay, name, "vcpkg.json")) {
				result = append(result, spec)
				goto next
			}
		}
		if fileExists(filepath.Join(config.Roots.Vcpkg, "ports", name, "vcpkg.json")) {
			result = append(result, spec)
		}
	next:
	}
	return uniqueStrings(result)
}

func mentionedTriplets(prompt string, config *RuntimeConfig) []string {
	var result []string
	for _, match := range portMention.FindAllString(prompt, -1) {
		name := strings.ToLower(match)
		if strings.Contains(name, "-") && resolveTripletPath(config, name) != "" {
			result = append(result, name)
		}
	}
	if len(result) == 0 && config.DefaultTriplet != "" {
		result = append(result, config.DefaultTriplet)
	}
	return uniqueStrings(result)
}

func mentionedFeatures(prompt string) []string {
	var result []string
	featurePattern := regexp.MustCompile(`(?i)(?:--x-feature(?:=|\s+)|feature(?:s)?\s+)([a-z0-9+_.-]+)`)
	for _, match := range featurePattern.FindAllStringSubmatch(prompt, -1) {
		if len(match) > 1 {
			result = append(result, match[1])
		}
	}
	return uniqueStrings(result)
}

func isDryRunPrompt(prompt string) bool {
	lower := strings.ToLower(prompt)
	return strings.Contains(lower, "dry run") || strings.Contains(lower, "dry-run") || strings.Contains(lower, "--dry-run")
}

func isUpdatePrompt(prompt string) bool {
	lower := strings.ToLower(prompt)
	return strings.Contains(lower, "update ") || strings.Contains(lower, "upgrade ") || strings.Contains(lower, "bump ") ||
		strings.Contains(lower, "latest stable") || strings.Contains(lower, "newer release")
}

func (t *Team) Run(ctx context.Context, prompt string) (FinalReport, error) {
	edges := newEdges()
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	var wait sync.WaitGroup
	runners := []func(context.Context){
		func(ctx context.Context) { t.planner.Run(ctx, t, edges) },
		func(ctx context.Context) { t.detector.Run(ctx, t, edges) },
		func(ctx context.Context) { t.installer.Run(ctx, t, edges) },
		func(ctx context.Context) { t.doctor.Run(ctx, t, edges) },
		func(ctx context.Context) { t.editor.Run(ctx, t, edges) },
		func(ctx context.Context) { t.triplet.Run(ctx, t, edges) },
		func(ctx context.Context) { t.baseline.Run(ctx, t, edges) },
	}
	for _, runner := range runners {
		wait.Add(1)
		go func() {
			defer wait.Done()
			runner(ctx)
		}()
	}
	t.planner.userPrompt = prompt
	if err := send(ctx, edges.UserRequest, UserRequest{
		Handoff: Handoff{Goal: "Satisfy this vcpkg request with a verified result or blocker.", Evidence: []string{"user prompt"}},
		Prompt:  prompt,
	}); err != nil {
		return FinalReport{}, err
	}
	close(edges.UserRequest)

	var final FinalReport
	var runErrors []error
	select {
	case final = <-edges.FinalReport:
	case err := <-edges.Errors:
		runErrors = append(runErrors, err)
	case <-ctx.Done():
		runErrors = append(runErrors, ctx.Err())
	}
	cancel()
	wait.Wait()
	close(edges.Errors)
	for err := range edges.Errors {
		runErrors = append(runErrors, err)
	}
	if len(runErrors) > 0 {
		return FinalReport{}, errors.Join(runErrors...)
	}
	return final, nil
}

func (p *Planner) Run(ctx context.Context, team *Team, edges *Edges) {
	defer close(edges.DetectRequest)
	defer close(edges.InstallRequest)
	defer close(edges.BaselineRequest)
	defer close(edges.FinalReport)
	user := edges.UserRequest
	installReport := edges.InstallReport
	blockers := edges.Blocker
	reinstall := edges.ReinstallRequest
	baselineReport := edges.BaselineReport
	for {
		select {
		case <-ctx.Done():
			return
		case message, ok := <-user:
			if !ok {
				user = nil
				continue
			}
			p.userPrompt = message.Prompt
			request := DetectRequest{
				Handoff:  Handoff{Goal: "Detect and verify the scenario, tools, triplets, roots, variables, and access.", Evidence: []string{"user prompt"}},
				Triplets: mentionedTriplets(message.Prompt, p.config), Features: mentionedFeatures(message.Prompt),
			}
			output, err := team.runTurn(ctx, p.Member, copyPrompt("send_detect_request", request))
			if err != nil {
				reportError(edges, err)
				return
			}
			sent, ok := output.(DetectRequest)
			if !ok {
				reportError(edges, fmt.Errorf("Planner handed off %T, expected DetectRequest", output))
				return
			}
			p.validateDetectRequest(&sent, request)
			if err := send(ctx, edges.DetectRequest, sent); err != nil {
				return
			}
		case environment, ok := <-edges.EnvReport:
			if !ok {
				continue
			}
			p.environment = &environment
			if len(environment.Blockers) > 0 {
				final := p.finalBlocked("environment", environment.Blockers, nil)
				p.sendFinal(ctx, team, edges, final)
				return
			}
			if isUpdatePrompt(p.userPrompt) {
				final := p.finalBlocked("unsupported-update-route", []string{
					"US-2 and US-3 are blocked by G-1: the fixed ideation has no Planner-to-Port-Editor route for update requests",
				}, nil)
				p.sendFinal(ctx, team, edges, final)
				return
			}
			requests := p.buildInstallRequests(environment)
			if len(requests) == 0 {
				p.sendFinal(ctx, team, edges, p.finalBlocked("plan", []string{"No installable ports were found in the user request."}, nil))
				return
			}
			batch := InstallBatch{
				Handoff:  Handoff{Goal: "Install or verify each request in this order.", Evidence: []string{environment.Handoff.Evidence[0], fmt.Sprintf("scenario:%s", environment.Scenario)}},
				Requests: requests,
			}
			output, err := team.runTurn(ctx, p.Member, copyPrompt("send_install_requests", batch))
			if err != nil {
				reportError(edges, err)
				return
			}
			sent, ok := output.(InstallBatch)
			if !ok {
				reportError(edges, fmt.Errorf("Planner handed off %T, expected InstallBatch", output))
				return
			}
			p.validateInstallBatch(&sent, batch)
			for index := range sent.Requests {
				sent.Requests[index].Handoff.Session = sent.Handoff.Session
				if err := send(ctx, edges.InstallRequest, sent.Requests[index]); err != nil {
					return
				}
			}
		case report, ok := <-installReport:
			if !ok {
				installReport = nil
				continue
			}
			p.pending = append(p.pending, report)
			p.changedPorts = append(p.changedPorts, report.ChangedPorts...)
			p.receivedInstalls++
			ledger := p.ledger(report)
			p.reportStatus = "finished"
			if len(report.Unresolved) > 0 {
				p.reportStatus = "blocked"
			}
			if p.environment != nil && p.environment.Scenario == "registry" && !report.DryRunOnly && len(p.changedPorts) > 0 {
				request := BaselineRequest{
					Handoff: Handoff{Goal: "Create two local commits per changed port: ports, then versions.", Evidence: uniqueStrings(p.changedPorts)},
					Ports:   uniqueStrings(p.changedPorts),
				}
				output, err := team.runTurn(ctx, p.Member, copyPrompt("send_baseline_request", request))
				if err != nil {
					reportError(edges, err)
					return
				}
				sent, ok := output.(BaselineRequest)
				if !ok {
					reportError(edges, fmt.Errorf("Planner handed off %T, expected BaselineRequest", output))
					return
				}
				sent = attachSession(request, team.session)
				if err := send(ctx, edges.BaselineRequest, sent); err != nil {
					return
				}
				continue
			}
			p.sendFinal(ctx, team, edges, p.finalFromLedger(p.reportStatus, ledger))
			return
		case blocker, ok := <-blockers:
			if !ok {
				blockers = nil
				continue
			}
			p.blockers = append(p.blockers, blocker)
			request := InstallRequest{
				Handoff: Handoff{Goal: "Mark the failed port unresolved and continue the remaining stack.", Evidence: blockerEvidence(blocker)},
				Triplet: blocker.Triplet, Reason: "continue", SkipSpec: blocker.Spec,
			}
			if err := send(ctx, edges.InstallRequest, request); err != nil {
				return
			}
		case request, ok := <-reinstall:
			if !ok {
				reinstall = nil
				continue
			}
			if request.Blocked {
				p.blockers = append(p.blockers, Blocker{
					Handoff: Handoff{Goal: "Report the triplet edit limit.", Evidence: []string{request.TripletFile, request.Reason}},
					Spec:    request.Triplet, Triplet: request.Triplet, Category: "triplet-edit-limit", Reason: request.Reason,
				})
				p.sendFinal(ctx, team, edges, p.finalBlocked("triplet-edit-limit", nil, nil))
				return
			}
			install := InstallRequest{
				Handoff: request.Handoff, Triplet: request.Triplet, Ports: request.Ports,
				ManifestRoot: request.ManifestRoot, Features: request.Features, Reason: "reinstall", Final: true,
			}
			install.Handoff.Goal = "Reinstall all affected ports after the triplet ABI change."
			if err := send(ctx, edges.InstallRequest, install); err != nil {
				return
			}
		case report, ok := <-baselineReport:
			if !ok {
				baselineReport = nil
				continue
			}
			ledger := p.combinedLedger()
			final := p.finalFromLedger(p.reportStatus, ledger)
			final.Commits = report.Commits
			p.sendFinal(ctx, team, edges, final)
			return
		}
	}
}

func (p *Planner) validateDetectRequest(got *DetectRequest, expected DetectRequest) {
	got.Handoff = attachSession(expected.Handoff, got.Session)
	got.Triplets = append([]string(nil), expected.Triplets...)
	got.Features = append([]string(nil), expected.Features...)
}

func (p *Planner) validateInstallBatch(got *InstallBatch, expected InstallBatch) {
	session := got.Session
	got.Handoff = expected.Handoff
	got.Session = session
	if len(got.Requests) != len(expected.Requests) {
		got.Requests = expected.Requests
	}
	for index := range got.Requests {
		got.Requests[index].Triplet = expected.Requests[index].Triplet
		got.Requests[index].Ports = expected.Requests[index].Ports
		got.Requests[index].Features = expected.Requests[index].Features
		got.Requests[index].ManifestRoot = expected.Requests[index].ManifestRoot
		got.Requests[index].Reason = expected.Requests[index].Reason
		got.Requests[index].DryRunOnly = expected.Requests[index].DryRunOnly
		got.Requests[index].Final = expected.Requests[index].Final
	}
}

func (p *Planner) buildInstallRequests(environment EnvReport) []InstallRequest {
	triplets := make([]string, 0, len(environment.Triplets))
	for _, triplet := range environment.Triplets {
		if triplet.Name != "" {
			triplets = append(triplets, triplet.Name)
		}
	}
	if len(triplets) == 0 {
		triplets = []string{p.config.DefaultTriplet}
	}
	ports := environment.PortsHint
	features := mentionedFeatures(p.userPrompt)
	result := make([]InstallRequest, 0, len(triplets))
	for _, triplet := range triplets {
		request := InstallRequest{
			Handoff: Handoff{Goal: "Verify or install this request serially.", Evidence: []string{environment.ScenarioEvidence[0], "triplet:" + triplet}},
			Triplet: triplet, Reason: "user", DryRunOnly: environment.DryRunOnly,
		}
		if environment.Scenario == "manifest" {
			request.ManifestRoot = p.config.ManifestRoot
			request.Features = features
		} else {
			request.Ports = append([]string(nil), ports...)
		}
		result = append(result, request)
	}
	if len(result) > 0 {
		result[len(result)-1].Final = true
	}
	return result
}

func (p *Planner) sendFinal(ctx context.Context, team *Team, edges *Edges, report FinalReport) {
	output, err := team.runTurn(ctx, p.Member, copyPrompt("send_final_report", report))
	if err != nil {
		reportError(edges, err)
		return
	}
	if _, ok := output.(FinalReport); !ok {
		reportError(edges, fmt.Errorf("Planner handed off %T, expected FinalReport", output))
		return
	}
	final := attachSession(report, team.session)
	_ = send(ctx, edges.FinalReport, final)
}

func (p *Planner) finalBlocked(reason string, messages []string, extra []Blocker) FinalReport {
	blockers := append([]Blocker(nil), extra...)
	for _, message := range messages {
		blockers = append(blockers, Blocker{
			Handoff:  Handoff{Goal: "Report this blocker to the user.", Evidence: []string{reason}},
			Category: reason, Reason: message,
		})
	}
	blockers = append(blockers, p.blockers...)
	return FinalReport{
		Handoff: Handoff{Goal: "Report the verified blocker.", Evidence: []string{reason}},
		Status:  "blocked", Scenario: p.config.Scenario, Warnings: p.config.Warnings, Blockers: blockers,
	}
}

func (p *Planner) ledger(report InstallReport) []LedgerEntry {
	var ledger []LedgerEntry
	for _, item := range report.Done {
		status := "verified"
		if !report.DryRunOnly {
			status = "installed"
		}
		ledger = append(ledger, LedgerEntry{Spec: item.Spec, Triplet: item.Triplet, Status: status, Evidence: item.Evidence})
	}
	for _, item := range report.Unresolved {
		ledger = append(ledger, LedgerEntry{Spec: item.Spec, Triplet: item.Triplet, Status: "blocked", Evidence: item.Evidence})
	}
	return ledger
}

func (p *Planner) combinedLedger() []LedgerEntry {
	var ledger []LedgerEntry
	for _, report := range p.pending {
		ledger = append(ledger, p.ledger(report)...)
	}
	return ledger
}

func (p *Planner) finalFromLedger(status string, ledger []LedgerEntry) FinalReport {
	warnings := append([]string(nil), p.config.Warnings...)
	if p.environment != nil {
		warnings = append(warnings, p.environment.Warnings...)
	}
	return FinalReport{
		Handoff: Handoff{Goal: "Report the verified result to the user.", Evidence: []string{"installation ledger"}},
		Status:  status, Scenario: p.config.Scenario, Ledger: ledger, Warnings: uniqueStrings(warnings), Blockers: p.blockers,
	}
}

func blockerEvidence(blocker Blocker) []string {
	result := []string{blocker.Category, blocker.Reason}
	for _, finding := range blocker.Findings {
		if finding.Source != "" {
			result = append(result, finding.Source)
		}
	}
	return uniqueStrings(result)
}

func (a *EnvironmentDetector) Run(ctx context.Context, team *Team, edges *Edges) {
	defer close(edges.EnvReport)
	defer close(edges.HostFacts)
	detect := edges.DetectRequest
	hostFacts := edges.HostFactsRequest
	for {
		select {
		case <-ctx.Done():
			return
		case request, ok := <-detect:
			if !ok {
				detect = nil
				continue
			}
			report := team.detectEnvironment(ctx, request)
			output, err := team.runTurn(ctx, a.Member, copyPrompt("send_env_report", report))
			if err != nil {
				reportError(edges, err)
				return
			}
			sent, ok := output.(EnvReport)
			if !ok {
				reportError(edges, fmt.Errorf("Environment Detector handed off %T, expected EnvReport", output))
				return
			}
			sent = report
			sent.Handoff.Session = team.session
			if err := send(ctx, edges.EnvReport, sent); err != nil {
				return
			}
		case request, ok := <-hostFacts:
			if !ok {
				hostFacts = nil
				continue
			}
			facts := HostFacts{
				Handoff:     Handoff{Goal: "Use these host facts to decide the triplet change.", Evidence: []string{runtime.GOOS, runtime.GOARCH, a.config.Roots.Vcpkg}},
				HostTriplet: a.config.HostTriplet, Compilers: compilerSummary(team, ctx, request.Goals.Triplet),
				SDKs: knownSDKs(), Notes: []string{request.Question}, Goals: request.Goals,
			}
			output, err := team.runTurn(ctx, a.Member, copyPrompt("send_host_facts", facts))
			if err != nil {
				reportError(edges, err)
				return
			}
			sent, ok := output.(HostFacts)
			if !ok {
				reportError(edges, fmt.Errorf("Environment Detector handed off %T, expected HostFacts", output))
				return
			}
			sent = facts
			sent.Handoff.Session = team.session
			if err := send(ctx, edges.HostFacts, sent); err != nil {
				return
			}
		}
	}
}

func compilerSummary(team *Team, ctx context.Context, triplet string) []string {
	fact, err := team.detectCompiler(ctx, triplet)
	if err != nil {
		return []string{fact.Error}
	}
	return []string{"triplet=" + fact.Name, "source=" + fact.Source, "supported=true"}
}

func knownSDKs() []string {
	var result []string
	for _, name := range []string{"ANDROID_NDK_HOME", "ANDROID_HOME", "VULKAN_SDK", "CUDA_TOOLKIT_ROOT_DIR", "ONEAPI_ROOT", "JAVA_HOME"} {
		if value, ok := os.LookupEnv(name); ok && value != "" {
			result = append(result, name+"=<set>")
		}
	}
	return result
}

func (i *PortInstaller) Run(ctx context.Context, team *Team, edges *Edges) {
	defer close(edges.InstallFailure)
	defer close(edges.InstallReport)
	requests := edges.InstallRequest
	retries := edges.RetryRequest
	for {
		shouldDrain := false
		select {
		case <-ctx.Done():
			return
		case request, ok := <-requests:
			if !ok {
				requests = nil
				continue
			}
			if request.Reason == "continue" && i.waiting {
				i.unresolved = append(i.unresolved, Unresolved{
					Spec: request.SkipSpec, Triplet: request.Triplet,
					Reason:   "Port Doctor could not resolve the failure with the current write scopes",
					Evidence: []string{"doctor blocker"},
				})
				if len(i.stack) > 0 {
					i.stack = i.stack[1:]
				}
				i.waiting = false
				shouldDrain = true
			} else {
				i.enqueue(request)
				shouldDrain = true
			}
		case retry, ok := <-retries:
			if !ok {
				retries = nil
				continue
			}
			if !i.waiting || len(i.stack) == 0 {
				reportError(edges, errors.New("RetryRequest arrived without a waiting install"))
				return
			}
			i.changed = append(i.changed, basePortName(retry.Spec))
			i.waiting = false
			shouldDrain = true
		}
		if shouldDrain {
			i.drain(ctx, team, edges)
		}
	}
}

func (i *PortInstaller) enqueue(request InstallRequest) {
	if request.Reason == "reinstall" {
		if i.waiting && len(i.stack) > 0 {
			i.stack = i.stack[1:]
		}
		i.waiting = false
	}
	items := splitInstallRequest(request)
	for _, item := range items {
		delete(i.attempts, item.Triplet+"|"+strings.Join(item.Ports, ","))
	}
	if request.Reason == "reinstall" {
		i.stack = append(items, i.stack...)
	} else {
		i.stack = append(i.stack, items...)
	}
	i.finalSeen = i.finalSeen || request.Final
	i.dryRunOnly = i.dryRunOnly || request.DryRunOnly
}

func splitInstallRequest(request InstallRequest) []InstallRequest {
	if request.Ports == nil || len(request.Ports) <= 1 {
		return []InstallRequest{request}
	}
	result := make([]InstallRequest, 0, len(request.Ports))
	for index, port := range request.Ports {
		item := request
		item.Ports = []string{port}
		item.Final = request.Final && index == len(request.Ports)-1
		result = append(result, item)
	}
	return result
}

func (i *PortInstaller) drain(ctx context.Context, team *Team, edges *Edges) {
	for !i.waiting && len(i.stack) > 0 {
		request := i.stack[0]
		key := request.Triplet + "|" + strings.Join(request.Ports, ",")
		i.attempts[key]++
		failure, result, success := team.performInstall(ctx, request)
		if success {
			i.done = append(i.done, result)
			i.stack = i.stack[1:]
			continue
		}
		failure.Attempt = i.attempts[key]
		if i.attempts[key] >= i.config.Options.MaxPortCycles {
			i.unresolved = append(i.unresolved, Unresolved{Spec: failure.Spec, Triplet: failure.Triplet,
				Reason:   fmt.Sprintf("port cycle limit %d reached: %s", i.config.Options.MaxPortCycles, failure.ResultCode),
				Evidence: append([]string{failure.OutputLog}, failure.ErrorLogs...)})
			i.stack = i.stack[1:]
			continue
		}
		output, err := team.runTurn(ctx, i.Member, copyPrompt("send_install_failure", failure))
		if err != nil {
			reportError(edges, err)
			return
		}
		sent, ok := output.(InstallFailure)
		if !ok {
			reportError(edges, fmt.Errorf("Port Installer handed off %T, expected InstallFailure", output))
			return
		}
		sent = failure
		sent.Handoff.Session = team.session
		i.waiting = true
		if err := send(ctx, edges.InstallFailure, sent); err != nil {
			return
		}
	}
	if len(i.stack) == 0 && !i.waiting && i.finalSeen {
		report := InstallReport{
			Handoff: Handoff{Goal: "Judge these verified installs and decide the final or baseline step.",
				Evidence: reportEvidence(i.done, i.unresolved)},
			Done: append([]SpecResult(nil), i.done...), Unresolved: append([]Unresolved(nil), i.unresolved...),
			ChangedPorts: uniqueStrings(i.changed), DryRunOnly: i.dryRunOnly,
		}
		output, err := team.runTurn(ctx, i.Member, copyPrompt("send_install_report", report))
		if err != nil {
			reportError(edges, err)
			return
		}
		sent, ok := output.(InstallReport)
		if !ok {
			reportError(edges, fmt.Errorf("Port Installer handed off %T, expected InstallReport", output))
			return
		}
		sent = report
		sent.Handoff.Session = team.session
		_ = send(ctx, edges.InstallReport, sent)
		i.finalSeen = false
		i.done = nil
		i.unresolved = nil
		i.dryRunOnly = false
	}
}

func reportEvidence(done []SpecResult, unresolved []Unresolved) []string {
	result := []string{"Port Installer command logs"}
	for _, item := range done {
		result = append(result, item.Evidence...)
	}
	for _, item := range unresolved {
		result = append(result, item.Evidence...)
	}
	return uniqueStrings(result)
}

func (d *PortDoctor) Run(ctx context.Context, team *Team, edges *Edges) {
	defer close(edges.PortGoals)
	defer close(edges.TripletGoals)
	defer close(edges.Blocker)
	failures := edges.InstallFailure
	for {
		select {
		case <-ctx.Done():
			return
		case failure, ok := <-failures:
			if !ok {
				failures = nil
				continue
			}
			prompt := d.prompt(failure)
			output, err := team.runTurn(ctx, d.Member, prompt)
			if err != nil {
				reportError(edges, err)
				return
			}
			switch sent := output.(type) {
			case PortGoals:
				sent = attachSession(sent, team.session)
				if sent.NewPort != "" {
					sent.Port = basePortName(sent.NewPort)
				} else {
					sent.Port = basePortName(failure.Spec)
				}
				sent.Spec = failure.Spec
				sent.Triplet = failure.Triplet
				sent.ManifestRoot = failure.ManifestRoot
				if !portNamePattern.MatchString(sent.Port) {
					reportError(edges, fmt.Errorf("Port Doctor returned invalid port name %q", sent.Port))
					return
				}
				sent.PortRoot = resolvePortRoot(team.config, sent.Port)
				scope := d.editorScope(sent)
				if !hasPortEditorTarget(team.config, sent, scope) {
					_ = send(ctx, edges.Blocker, Blocker{
						Handoff: Handoff{Goal: "Report the unwritable fix target.", Evidence: []string{failure.OutputLog}},
						Spec:    failure.Spec, Triplet: failure.Triplet, Category: "permission",
						Reason: "Port Doctor selected a port or manifest target outside the configured write scopes",
					})
					continue
				}
				team.editor.setScope(scope)
				_ = send(ctx, edges.PortGoals, sent)
			case TripletGoals:
				sent = attachSession(sent, team.session)
				sent.Triplet = failure.Triplet
				if !wordPattern.MatchString(sent.Triplet) {
					reportError(edges, fmt.Errorf("Port Doctor returned invalid triplet name %q", sent.Triplet))
					return
				}
				sent.OverlayRoot = writableTripletOverlay(team.config)
				sent.TripletFile = resolveTripletPath(team.config, sent.Triplet)
				sent.Ports = []string{basePortName(failure.Spec)}
				sent.Features = append([]string(nil), failure.Features...)
				sent.ManifestRoot = failure.ManifestRoot
				if sent.OverlayRoot == "" {
					_ = send(ctx, edges.Blocker, Blocker{
						Handoff: Handoff{Goal: "Report the unwritable triplet target.", Evidence: []string{failure.OutputLog}},
						Spec:    failure.Spec, Triplet: failure.Triplet, Category: "permission",
						Reason: "No writable overlay triplet folder is configured",
					})
					continue
				}
				scope := d.tripletScope(sent)
				team.triplet.setScope(scope)
				_ = send(ctx, edges.TripletGoals, sent)
			case Blocker:
				sent = attachSession(sent, team.session)
				_ = send(ctx, edges.Blocker, sent)
			default:
				reportError(edges, fmt.Errorf("Port Doctor handed off unexpected %T", output))
				return
			}
		}
	}
}

func (d *PortDoctor) prompt(failure InstallFailure) string {
	evidence, _ := json.Marshal(failure)
	return fmt.Sprintf(`Diagnose this failure and call one of send_port_goals, send_triplet_goals, or send_blocker.
If the fix target is not writable in the current scope, send_blocker.
Allowed writes: %s. Immutable roots are configured by the CLI, not by the handoff.
Deterministic axis hint: %s.
Failure:
%s`, d.config.writeSummary(), diagnosisAxis(failure), evidence)
}

func diagnosisAxis(failure InstallFailure) string {
	text := strings.ToLower(strings.Join(append([]string{failure.Stage, failure.ResultCode}, failure.ErrorLogs...), " "))
	switch {
	case strings.Contains(text, "patch"), strings.Contains(text, "hash"):
		return "source or port patch"
	case strings.Contains(text, "compiler"), strings.Contains(text, "toolchain"), strings.Contains(text, "sdk"):
		return "toolchain"
	case strings.Contains(text, "post-build"), strings.Contains(text, "install"),
		strings.Contains(text, "post_install"), strings.Contains(text, "package layout"):
		return "installation"
	case strings.Contains(text, "cmake"), strings.Contains(text, "meson"), strings.Contains(text, "configure"),
		strings.Contains(text, "build"):
		return "build configuration"
	default:
		return "misc"
	}
}

func (d *PortDoctor) editorScope(goals PortGoals) Scope {
	scope := teamBaseScope(d.Member.Scope().CWD, d.config)
	scope.Network = []string{"*"}
	scope.Write = append(scope.Write, d.config.Scratch)
	if goals.PortRoot != "" && d.config.allowed("overlays") && insideAny(goals.PortRoot, d.config.OverlayPorts) {
		scope.Write = append(scope.Write, goals.PortRoot)
	} else if d.config.Scenario == "registry" && d.config.allowed("ports") {
		scope.Write = append(scope.Write, filepath.Join(d.config.Workspace, "ports", goals.Port))
	} else if d.config.Scenario == "manifest" && d.config.allowed("create-overlays") {
		scope.Write = append(scope.Write, filepath.Join(d.config.Workspace, "ports", goals.Port))
	}
	if d.config.Scenario == "manifest" {
		if d.config.allowed("manifest") {
			scope.Write = append(scope.Write, filepath.Join(d.config.ManifestRoot, "vcpkg.json"), filepath.Join(d.config.ManifestRoot, "vcpkg-configuration.json"))
		}
	}
	scope.Shell = dPortEditorShell()
	return scope
}

func hasPortEditorTarget(config *RuntimeConfig, goals PortGoals, scope Scope) bool {
	if goals.PortRoot != "" && insideAny(goals.PortRoot, scope.Write) {
		return true
	}
	if config.Scenario == "registry" && config.allowed("ports") {
		return true
	}
	if config.Scenario == "manifest" && config.allowed("manifest") {
		return true
	}
	if config.Scenario == "manifest" && config.allowed("create-overlays") {
		return true
	}
	return false
}

func (d *PortDoctor) tripletScope(goals TripletGoals) Scope {
	scope := teamBaseScope(d.Member.Scope().CWD, d.config)
	scope.Network = []string{"learn.microsoft.com", "github.com", "api.github.com"}
	if goals.OverlayRoot != "" && (d.config.allowed("triplets") || d.config.allowed("overlays")) {
		scope.Write = append(scope.Write, goals.OverlayRoot)
	}
	return scope
}

func teamBaseScope(cwd string, config *RuntimeConfig) Scope {
	return Scope{CWD: cwd, Read: configReadRoots(config)}
}

func dPortEditorShell() []ShellRule {
	return []ShellRule{
		{Program: "git", Prefix: []string{"diff"}, ReadOnly: true},
		{Program: "git", Prefix: []string{"status"}, ReadOnly: true},
	}
}

func writableTripletOverlay(config *RuntimeConfig) string {
	for _, root := range config.OverlayTriplets {
		if config.allowed("triplets") || config.allowed("overlays") {
			return root
		}
	}
	return ""
}

func (e *PortEditor) Run(ctx context.Context, team *Team, edges *Edges) {
	defer close(edges.RetryRequest)
	goals := edges.PortGoals
	for {
		select {
		case <-ctx.Done():
			return
		case request, ok := <-goals:
			if !ok {
				goals = nil
				continue
			}
			scope := team.doctor.editorScope(request)
			restore := e.withScope(scope)
			promptBytes, _ := json.Marshal(request)
			output, err := team.runTurn(ctx, e.Member, "Apply the smallest port fix for these goals, verify it, then call send_retry_request:\n"+string(promptBytes))
			restore()
			if err != nil {
				reportError(edges, err)
				return
			}
			sent, ok := output.(RetryRequest)
			if !ok {
				reportError(edges, fmt.Errorf("Port Editor handed off %T, expected RetryRequest", output))
				return
			}
			sent = attachSession(sent, team.session)
			sent.Spec = request.Spec
			sent.Triplet = request.Triplet
			_ = send(ctx, edges.RetryRequest, sent)
		}
	}
}

func (e *TripletEditor) Run(ctx context.Context, team *Team, edges *Edges) {
	defer close(edges.ReinstallRequest)
	defer close(edges.HostFactsRequest)
	goals := edges.TripletGoals
	facts := edges.HostFacts
	for {
		select {
		case <-ctx.Done():
			return
		case request, ok := <-goals:
			if !ok {
				goals = nil
				continue
			}
			if blocked, exhausted := e.tripletEditLimit(request); exhausted {
				output, err := team.runTurn(ctx, e.Member, copyPrompt("send_reinstall_request", blocked))
				if err != nil {
					reportError(edges, err)
					return
				}
				if _, ok := output.(ReinstallRequest); !ok {
					reportError(edges, fmt.Errorf("Triplet Editor handed off %T, expected ReinstallRequest", output))
					return
				}
				_ = send(ctx, edges.ReinstallRequest, attachSession(blocked, team.session))
				continue
			}
			scope := team.doctor.tripletScope(request)
			restore := e.withScope(scope)
			promptBytes, _ := json.Marshal(request)
			output, err := team.runTurn(ctx, e.Member, "Apply one triplet fix, or ask for host facts if required. End with one handoff:\n"+string(promptBytes))
			restore()
			if err != nil {
				reportError(edges, err)
				return
			}
			switch sent := output.(type) {
			case HostFactsRequest:
				sent.Goals = request
				sent = attachSession(sent, team.session)
				_ = send(ctx, edges.HostFactsRequest, sent)
			case ReinstallRequest:
				sent.Triplet = request.Triplet
				sent.Ports = append([]string(nil), request.Ports...)
				sent.Features = append([]string(nil), request.Features...)
				sent.ManifestRoot = request.ManifestRoot
				e.edits[sent.Triplet]++
				sent = attachSession(sent, team.session)
				_ = send(ctx, edges.ReinstallRequest, sent)
			default:
				reportError(edges, fmt.Errorf("Triplet Editor handed off unexpected %T", output))
				return
			}
		case host, ok := <-facts:
			if !ok {
				facts = nil
				continue
			}
			promptBytes, _ := json.Marshal(host)
			output, err := team.runTurn(ctx, e.Member, "Use these host facts to make one verified triplet edit, then call send_reinstall_request:\n"+string(promptBytes))
			if err != nil {
				reportError(edges, err)
				return
			}
			sent, ok := output.(ReinstallRequest)
			if !ok {
				reportError(edges, fmt.Errorf("Triplet Editor handed off %T, expected ReinstallRequest", output))
				return
			}
			if sent.Blocked {
				_ = send(ctx, edges.ReinstallRequest, attachSession(sent, team.session))
				continue
			}
			sent.Triplet = host.Goals.Triplet
			sent.Ports = append([]string(nil), host.Goals.Ports...)
			sent.Features = append([]string(nil), host.Goals.Features...)
			sent.ManifestRoot = host.Goals.ManifestRoot
			e.edits[sent.Triplet]++
			sent = attachSession(sent, team.session)
			_ = send(ctx, edges.ReinstallRequest, sent)
		}
	}
}

func (e *TripletEditor) tripletEditLimit(request TripletGoals) (ReinstallRequest, bool) {
	if e.edits[request.Triplet] < e.config.Options.MaxTripletEdits {
		return ReinstallRequest{}, false
	}
	return ReinstallRequest{
		Handoff: Handoff{
			Goal:     "Report the triplet edit budget as a blocker.",
			Evidence: []string{request.TripletFile},
		},
		Triplet: request.Triplet, Blocked: true,
		Reason: fmt.Sprintf("triplet edit limit %d reached", e.config.Options.MaxTripletEdits),
	}, true
}

func (b *BaselineUpdater) Run(ctx context.Context, team *Team, edges *Edges) {
	defer close(edges.BaselineReport)
	requests := edges.BaselineRequest
	for {
		select {
		case <-ctx.Done():
			return
		case request, ok := <-requests:
			if !ok {
				requests = nil
				continue
			}
			scope := b.Member.Scope()
			for _, port := range request.Ports {
				scope.Write = append(scope.Write, filepath.Join(b.config.Workspace, "ports", port))
			}
			scope.Write = append(scope.Write, filepath.Join(b.config.Workspace, "versions"))
			restore := b.withScope(scope)
			promptBytes, _ := json.Marshal(request)
			output, err := team.runTurn(ctx, b.Member,
				"For each port in order, call version_update stage format, git_commit ports, version_update stage versions, git_commit versions; then call send_baseline_report:\n"+string(promptBytes))
			restore()
			if err != nil {
				reportError(edges, err)
				return
			}
			sent, ok := output.(BaselineReport)
			if !ok {
				reportError(edges, fmt.Errorf("Baseline Updater handed off %T, expected BaselineReport", output))
				return
			}
			if err := team.validateBaselineReport(request, sent); err != nil {
				reportError(edges, err)
				return
			}
			sent = attachSession(sent, team.session)
			_ = send(ctx, edges.BaselineReport, sent)
		}
	}
}

func (t *Team) validateBaselineReport(request BaselineRequest, report BaselineReport) error {
	if len(report.Skipped) > 0 {
		return fmt.Errorf("Baseline Updater skipped changed ports after install: %s", strings.Join(report.Skipped, ", "))
	}
	skipped := make(map[string]bool)
	for _, port := range report.Skipped {
		skipped[basePortName(port)] = true
	}
	var activePorts []string
	for _, port := range request.Ports {
		if !skipped[basePortName(port)] {
			activePorts = append(activePorts, basePortName(port))
		}
	}
	expected := len(activePorts) * 2
	if len(report.Commits) != expected {
		return fmt.Errorf("Baseline Updater reported %d commits; want %d (two per port not skipped)", len(report.Commits), expected)
	}
	for index, port := range activePorts {
		portCommit := report.Commits[index*2]
		versionCommit := report.Commits[index*2+1]
		portRoot := filepath.Join(t.config.Workspace, "ports", port)
		versionRoot := filepath.Join(t.config.Workspace, "versions")
		if err := t.validateCommit(portCommit, portRoot); err != nil {
			return fmt.Errorf("port commit for %s: %w", port, err)
		}
		if err := t.validateCommit(versionCommit, versionRoot); err != nil {
			return fmt.Errorf("version commit for %s: %w", port, err)
		}
		if err := t.validateCommittedVersionRecord(port, portCommit.Hash, versionCommit.Hash); err != nil {
			return err
		}
		if output, err := t.runGit(context.Background(), t.config.Workspace,
			"merge-base", "--is-ancestor", portCommit.Hash, versionCommit.Hash); err != nil {
			return fmt.Errorf("version commit does not follow the port commit: %w: %s", err, output)
		}
	}
	return nil
}

func (t *Team) validateCommittedVersionRecord(port, portCommit, versionCommit string) error {
	tree, err := t.runGit(context.Background(), t.config.Workspace, "rev-parse",
		portCommit+":"+filepath.ToSlash(filepath.Join("ports", port)))
	if err != nil {
		return fmt.Errorf("read committed port tree for %s: %w: %s", port, err, tree)
	}
	record := filepath.ToSlash(filepath.Join("versions", strings.ToLower(port[:1])+"-", port+".json"))
	data, err := t.runGit(context.Background(), t.config.Workspace, "show", versionCommit+":"+record)
	if err != nil {
		return fmt.Errorf("version commit lacks %s: %w: %s", record, err, data)
	}
	var decoded struct {
		Versions []struct {
			GitTree string `json:"git-tree"`
		} `json:"versions"`
	}
	if err := json.Unmarshal([]byte(data), &decoded); err != nil {
		return fmt.Errorf("parse committed version record %s: %w", record, err)
	}
	for _, version := range decoded.Versions {
		if version.GitTree == strings.TrimSpace(tree) {
			return nil
		}
	}
	return fmt.Errorf("committed version record %s does not contain port git-tree %s", record, strings.TrimSpace(tree))
}

func (t *Team) validateCommit(commit Commit, expectedRoot string) error {
	if !commitHashPattern.MatchString(commit.Hash) {
		return fmt.Errorf("invalid commit hash %q", commit.Hash)
	}
	if output, err := t.runGit(context.Background(), t.config.Workspace, "cat-file", "-e", commit.Hash+"^{commit}"); err != nil {
		return fmt.Errorf("commit %s is not in the repository: %w: %s", commit.Hash, err, output)
	}
	output, err := t.runGit(context.Background(), t.config.Workspace,
		"diff-tree", "--root", "--no-commit-id", "--name-only", "-r", commit.Hash)
	if err != nil {
		return fmt.Errorf("read paths for commit %s: %w: %s", commit.Hash, err, output)
	}
	actual := strings.Fields(output)
	if len(actual) == 0 {
		return fmt.Errorf("commit %s changed no files", commit.Hash)
	}
	if len(commit.Paths) == 0 {
		return fmt.Errorf("commit %s reports no paths", commit.Hash)
	}
	reported := make([]string, 0, len(commit.Paths))
	for _, path := range commit.Paths {
		absolute := path
		if !filepath.IsAbs(absolute) {
			absolute = filepath.Join(t.config.Workspace, path)
		}
		if !insideAny(absolute, []string{expectedRoot}) {
			return fmt.Errorf("reported path %s is outside %s", path, expectedRoot)
		}
		reported = append(reported, absolute)
	}
	for _, path := range actual {
		absolute := filepath.Join(t.config.Workspace, filepath.FromSlash(path))
		if !insideAny(absolute, []string{expectedRoot}) {
			return fmt.Errorf("actual path %s is outside %s", path, expectedRoot)
		}
		covered := false
		for _, reportRoot := range reported {
			if insideAny(absolute, []string{reportRoot}) {
				covered = true
				break
			}
		}
		if !covered {
			return fmt.Errorf("actual path %s is not covered by report.Paths", path)
		}
	}
	return nil
}

func sanitizeName(value string) string {
	var result strings.Builder
	for _, r := range strings.ToLower(value) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			result.WriteRune(r)
		} else {
			result.WriteByte('-')
		}
	}
	return strings.Trim(result.String(), "-")
}

func sanitizePatchName(value string) string {
	name := strings.TrimSpace(filepath.Base(value))
	name = strings.TrimSuffix(name, ".patch")
	if name == "" || !portNamePattern.MatchString(name) {
		name = "fix"
	}
	return name
}

func copyTree(source, destination string) error {
	info, err := os.Stat(source)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return fmt.Errorf("%s is not a directory", source)
	}
	return filepath.WalkDir(source, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		relative, err := filepath.Rel(source, path)
		if err != nil {
			return err
		}
		target := filepath.Join(destination, relative)
		if entry.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		if entry.Type()&os.ModeSymlink != 0 {
			link, err := os.Readlink(path)
			if err != nil {
				return err
			}
			if filepath.IsAbs(link) {
				return fmt.Errorf("absolute symlink in patch source is not allowed: %s", path)
			}
			return os.Symlink(link, target)
		}
		entryInfo, err := entry.Info()
		if err != nil {
			return err
		}
		src, err := os.Open(path)
		if err != nil {
			return err
		}
		defer src.Close()
		dst, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, entryInfo.Mode().Perm())
		if err != nil {
			return err
		}
		_, copyErr := io.Copy(dst, src)
		closeErr := dst.Close()
		return errors.Join(copyErr, closeErr)
	})
}

func main() {
	options, err := ParseOptions(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	SetupLogging(os.Stderr, options.Verbose)
	config, err := LoadRuntimeConfig(options)
	if err != nil {
		slog.Error("initialize", "error", err)
		os.Exit(1)
	}
	defer func() {
		if cleanupErr := config.Cleanup(); cleanupErr != nil {
			slog.Warn("cleanup", "error", cleanupErr)
		}
	}()
	ctx := context.Background()
	team := NewTeam(config)
	if err := team.CreateSession(ctx); err != nil {
		slog.Error("create session", "error", err)
		os.Exit(1)
	}
	defer team.Close()
	report, err := team.Run(ctx, options.Prompt)
	if err != nil {
		slog.Error("team", "error", err)
		os.Exit(1)
	}
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(report); err != nil {
		slog.Error("write final report", "error", err)
		os.Exit(1)
	}
}
