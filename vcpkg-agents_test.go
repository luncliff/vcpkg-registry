package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"runtime"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	copilot "github.com/microsoft/copilot-sdk/go/v2"
	"github.com/microsoft/copilot-sdk/go/v2/rpc"
)

func TestParseOptionsDefaultModelAndScopes(t *testing.T) {
	options, err := ParseOptions([]string{
		"--prompt", "Dry run zlib-ng"})
	if err != nil {
		t.Fatal(err)
	}
	if options.Model != "gpt-6-luna" {
		t.Fatalf("model = %q, want gpt-6-luna", options.Model)
	}
	_, err = ParseOptions([]string{"--prompt", "x", "--write", "unknown"})
	if err == nil || !strings.Contains(err.Error(), "unknown") {
		t.Fatalf("unknown write scope error = %v", err)
	}
	if _, err = ParseOptions([]string{"--prompt", "x", "--sandbox"}); err == nil {
		t.Fatal("unused sandbox option remains accepted")
	}
}
func TestLoadRuntimeConfigDetectsRegistryAndManifest(t *testing.T) {
	t.Run("registry", func(t *testing.T) {
		root := createRegistryFixture(t, "agent-config-ok", successfulPortfile())
		initGitRepository(t, root)
		logRoot := t.TempDir()
		withWorkingDirectory(t, root, func() {
			options, err := ParseOptions([]string{"--prompt", "Dry run agent-config-ok", "--log-dir", logRoot, "--overlay-ports", filepath.Join(root, "ports"), "--x-buildtrees-root", filepath.Join(root, "buildtrees"), "--x-packages-root", filepath.Join(root, "packages"), "--x-install-root", filepath.Join(root, "installed")})
			if err != nil {
				t.Fatal(err)
			}
			config, err := LoadRuntimeConfig(options)
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() {
				_ = config.Cleanup()
			})
			if config.Scenario != "registry" {
				t.Fatalf("scenario = %q", config.Scenario)
			}
			if !samePath(config.WorkingDirectory, root) || !samePath(config.Workspace, root) || !samePath(sessionOptions(config, options).WorkingDirectory, root) {
				t.Fatalf("invocation workspace = %q, %q", config.WorkingDirectory, config.Workspace)
			}
			if !containsPath(config.OverlayPorts, filepath.Join(root, "ports")) {
				t.Fatalf("registry ports overlay missing: %v", config.OverlayPorts)
			}
			if !insideAny(config.LogDirectory, []string{logRoot}) || !containsPath(configReadRoots(config), config.LogDirectory) {
				t.Fatalf("retained log directory outside configured roots: %s", config.LogDirectory)
			}
			logFile := filepath.Join(config.LogDirectory, "command-test.log")
			writeFile(t, logFile, "command output")
			if err := config.Cleanup(); err != nil || isDir(config.Scratch) || !fileExists(logFile) {
				t.Fatalf("cleanup = %v; want scratch removed and command log retained", err)
			}
		})
	})
	t.Run("manifest", func(t *testing.T) {
		root := t.TempDir()
		writeFile(t, filepath.Join(root, "vcpkg.json"), `{"dependencies":["zlib"]}`)
		withWorkingDirectory(t, root, func() {
			options, err := ParseOptions([]string{"--prompt", "Dry run", "--x-manifest-root", root})
			if err != nil {
				t.Fatal(err)
			}
			config, err := LoadRuntimeConfig(options)
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() {
				_ = config.Cleanup()
			})
			if config.Scenario != "manifest" || !samePath(config.ManifestRoot, root) {
				t.Fatalf("manifest detection = %q, %q", config.Scenario, config.ManifestRoot)
			}
		})
	})
	t.Run("empty default triplet", func(t *testing.T) {
		t.Setenv("VCPKG_DEFAULT_TRIPLET", "")
		root := createRegistryFixture(t, "agent-config-ok", successfulPortfile())
		withWorkingDirectory(t, root, func() {
			options, err := ParseOptions([]string{"--prompt", "dry run install agent-config-ok"})
			if err != nil {
				t.Fatal(err)
			}
			config, err := LoadRuntimeConfig(options)
			if err != nil {
				t.Fatal(err)
			}
			defer config.Cleanup()
			blockers := strings.Join(config.Blockers, "\n")
			if !strings.Contains(blockers, "VCPKG_DEFAULT_TRIPLET is set but empty") || !strings.Contains(blockers, "Invalid triplet:") || !strings.Contains(blockers, "Built-in Triplets:") {
				t.Fatalf("default triplet blockers = %q", blockers)
			}
		})
	})
	t.Run("registry version preconditions", func(t *testing.T) {
		root := createRegistryFixture(t, "agent-crlf", successfulPortfile())
		initGitRepository(t, root)
		runGitForTest(t, root, "config", "core.autocrlf", "true")
		manifest := filepath.Join(root, "ports", "agent-crlf", "vcpkg.json")
		writeFile(t, manifest, strings.ReplaceAll(readFile(t, manifest), "\n", "\r\n"))
		withWorkingDirectory(t, root, func() {
			options, err := ParseOptions([]string{"--prompt", "Update agent-crlf"})
			if err != nil {
				t.Fatal(err)
			}
			config, err := LoadRuntimeConfig(options)
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() {
				_ = config.Cleanup()
			})
			joined := strings.Join(config.Blockers, "\n")
			if !strings.Contains(joined, "core.autocrlf") || !strings.Contains(joined, "CRLF") {
				t.Fatalf("version precondition blockers = %v", config.Blockers)
			}
		})
	})
}
func TestEnvironmentDetectorVariableBlockersAndScrubbing(t *testing.T) {
	t.Setenv("VCPKG_DEFAULT_TRIPLET", "")
	t.Setenv("VCPKG_BINARY_SOURCES", "clear;files,/secret?sig=secret-value,rw")
	t.Setenv("GITHUB_TOKEN", "github-token-value")
	t.Setenv("VCPKG_FEATURE_FLAGS", "dependencygraph,registries")
	t.Setenv("VCPKG_KEEP_ENV_VARS", "GITHUB_TOKEN")
	variables, _, blockers := inspectVcpkgVariables()
	foundEmpty, foundSecretStructure := false, false
	for _, variable := range variables {
		switch variable.Name {
		case "VCPKG_DEFAULT_TRIPLET":
			foundEmpty = variable.Blocker && variable.SafeValue == ""
		case "VCPKG_BINARY_SOURCES":
			foundSecretStructure = variable.Secret && variable.SafeValue == ""
		}
	}
	if !foundEmpty || !foundSecretStructure {
		t.Fatalf("variable statuses incomplete: %+v", variables)
	}
	if len(blockers) == 0 {
		t.Fatal("empty VCPKG_DEFAULT_TRIPLET did not block")
	}
	env := scrubbedVcpkgEnvironment(os.Environ(), nil)
	joined := strings.Join(env, "\n")
	for _, pair := range env {
		if strings.HasPrefix(pair, "GITHUB_TOKEN=") || strings.HasPrefix(pair, "GH_TOKEN=") {
			t.Fatal("GitHub credential leaked into vcpkg environment")
		}
	}
	if !strings.Contains(joined, "VCPKG_BINARY_SOURCES=") {
		t.Fatal("vcpkg binary source was incorrectly removed")
	}
	if !strings.Contains(joined, "VCPKG_FEATURE_FLAGS=-dependencygraph,registries") && !strings.Contains(joined, "VCPKG_FEATURE_FLAGS=registries,-dependencygraph") {
		t.Fatalf("dependencygraph was not disabled: %s", joined)
	}
	redacted := redactText("on expression: files,/secret?sig=secret-value", collectSecretValues())
	if strings.Contains(redacted, "secret-value") {
		t.Fatal("known secret remained after redaction")
	}
}
func TestScrubbedVcpkgEnvironmentKeepsWindowsSystemVariables(t *testing.T) {
	if runtime.GOOS != "windows" {
		t.Skip("Windows environment names are case-insensitive")
	}
	want := []string{`Path=C:\tools`, `SystemRoot=C:\Windows`, `ComSpec=C:\Windows\System32\cmd.exe`, `ProgramData=C:\ProgramData`, `SystemDrive=C:`}
	if got := scrubbedVcpkgEnvironment(append(slices.Clone(want), "Gh_Token=discard"), nil); !slices.Equal(got, want) {
		t.Fatalf("scrubbed environment = %v, want %v", got, want)
	}
}
func TestGHReadAllowlistRejectsWrites(t *testing.T) {
	allowed := [][]string{{"search", "issues", "port failure"}, {"api", "repos/microsoft/vcpkg/commits"}, {"api", "--method", "GET", "repos/microsoft/vcpkg/issues"}, {"pr", "diff", "1"}}
	denied := [][]string{{"issue", "create"}, {"pr", "create"}, {"api", "--method", "POST", "repos/x/y/issues"}, {"api", "--method=POST", "repos/x/y/issues"}, {"api", "-XPOST", "repos/x/y/issues"}, {"api", "--method", "GET", "--method", "POST", "repos/x/y/issues"}, {"api", "graphql", "-f", "query=mutation { x }"}, {"api", "-X", "DELETE", "repos/x/y"}, {"api", "--field", "body=x", "repos/x/y"}}
	for _, args := range allowed {
		if !isReadOnlyGH(args) {
			t.Errorf("read command denied: %v", args)
		}
	}
	for _, args := range denied {
		if isReadOnlyGH(args) {
			t.Errorf("write command allowed: %v", args)
		}
	}
}
func TestPathGuardRejectsSiblingAndSymlinkEscape(t *testing.T) {
	root := filepath.Join(t.TempDir(), "root")
	mustMkdir(t, root)
	if insideAny(filepath.Join(root, "..", "outside.txt"), []string{root}) {
		t.Fatal("sibling path escaped root")
	}
	link := filepath.Join(root, "escape")
	outside := filepath.Join(t.TempDir(), "outside")
	mustMkdir(t, outside)
	if err := os.Symlink(outside, link); err != nil {
		t.Skipf("symlink unavailable: %v", err)
	}
	if insideAny(filepath.Join(link, "secret.txt"), []string{root}) {
		t.Fatal("symlink escape was allowed")
	}
	broken := filepath.Join(root, "broken")
	missingTarget := filepath.Join(t.TempDir(), "missing-target")
	if err := os.Symlink(missingTarget, broken); err != nil {
		t.Skipf("dangling symlink unavailable: %v", err)
	}
	if insideAny(filepath.Join(broken, "new.txt"), []string{root}) {
		t.Fatal("dangling symlink was allowed")
	}
}
func newTestRuntimeConfig(t *testing.T, scenario string) *RuntimeConfig {
	t.Helper()
	workspace := t.TempDir()
	scratch := filepath.Join(workspace, ".scratch")
	logs := filepath.Join(scratch, "logs")
	for _, path := range []string{filepath.Join(workspace, "ports"), filepath.Join(workspace, "triplets"), filepath.Join(workspace, "versions"), logs, filepath.Join(scratch, "buildtrees"), filepath.Join(scratch, "downloads"), filepath.Join(scratch, "installed"), filepath.Join(scratch, "packages")} {
		mustMkdir(t, path)
	}
	tools := make(map[string]string)
	for _, name := range []string{"vcpkg", "git", "gh", "cmake", "ninja", "pwsh", "powershell", "bash", "curl", "tar", "copilot"} {
		if path, err := exec.LookPath(name); err == nil {
			tools[name], _ = filepath.Abs(path)
		}
	}
	if tools["vcpkg"] == "" {
		t.Skip("vcpkg not found")
	}
	roots := VcpkgRoots{Vcpkg: currentVcpkgRoot(t, tools["vcpkg"]), Buildtrees: filepath.Join(scratch, "buildtrees"), Downloads: filepath.Join(scratch, "downloads"), Installed: filepath.Join(scratch, "installed"), Packages: filepath.Join(scratch, "packages")}
	triplet := "x64-linux"
	if runtime.GOOS == "windows" {
		triplet = "x64-windows"
	} else if runtime.GOOS == "darwin" {
		triplet = "x64-osx"
	}
	writeScopes := defaultWriteScopes(scenario)
	return &RuntimeConfig{WorkingDirectory: workspace, Workspace: workspace, Scenario: scenario, Tools: tools, Roots: roots, OverlayPorts: []string{filepath.Join(workspace, "ports")}, OverlayTriplets: []string{filepath.Join(workspace, "triplets")}, HostTriplet: triplet, VcpkgEnv: scrubbedVcpkgEnvironment(os.Environ(), nil), Scratch: scratch, LogDirectory: logs, WriteScopes: writeScopes, SecretValues: collectSecretValues()}
}
func createPortFixture(t *testing.T, portsRoot, name string) string {
	t.Helper()
	return createPortFixtureAt(t, portsRoot, name, successfulPortfile())
}
func createPortFixtureAt(t *testing.T, portsRoot, name, portfile string) string {
	t.Helper()
	root := filepath.Join(portsRoot, name)
	manifest := fmt.Sprintf(`{
  "name": %q,
  "version": "1.0.0",
  "description": "vcpkg agent team test fixture",
  "license": "MIT"
}`, name)
	writeFile(t, filepath.Join(root, "vcpkg.json"), manifest)
	writeFile(t, filepath.Join(root, "portfile.cmake"), portfile)
	return root
}
func assertApproved(t *testing.T, decision rpc.PermissionDecision, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
	switch decision.(type) {
	case *rpc.PermissionDecisionApproved, *rpc.PermissionDecisionApproveOnce, *rpc.PermissionDecisionApproveForSession:
		return
	default:
		t.Fatalf("decision = %T, want approved", decision)
	}
}
func assertRejected(t *testing.T, decision rpc.PermissionDecision, err error, contains string) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
	rejected, ok := decision.(*rpc.PermissionDecisionReject)
	if !ok {
		t.Fatalf("decision = %T, want reject", decision)
	}
	if rejected.Feedback == nil || !strings.Contains(*rejected.Feedback, contains) {
		t.Fatalf("feedback = %v, want %q", rejected.Feedback, contains)
	}
}
func initGitRepository(t *testing.T, root string) {
	t.Helper()
	runGitForTest(t, root, "init")
	runGitForTest(t, root, "config", "user.name", "vcpkg-agents-test")
	runGitForTest(t, root, "config", "user.email", "vcpkg-agents-test@localhost")
	runGitForTest(t, root, "config", "core.autocrlf", "false")
}
func runGitForTest(t *testing.T, root string, args ...string) string {
	t.Helper()
	command := exec.Command("git", append([]string{"-C", root}, args...)...)
	output, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, output)
	}
	return strings.TrimSpace(string(output))
}
func writeFile(t *testing.T, path, content string) {
	t.Helper()
	mustMkdir(t, filepath.Dir(path))
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}
func readFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}
func mustMkdir(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(path, 0o755); err != nil {
		t.Fatal(err)
	}
}
func currentVcpkgRoot(t *testing.T, vcpkg string) string {
	t.Helper()
	ctx := context.Background()
	output, err := exec.CommandContext(ctx, vcpkg, "z-print-config", "--disable-metrics").Output()
	if err != nil {
		t.Fatalf("vcpkg z-print-config: %v", err)
	}
	var printed vcpkgConfiguration
	if err := json.Unmarshal(output, &printed); err != nil {
		t.Fatal(err)
	}
	return printed.VcpkgRoot
}

func createRegistryFixture(t *testing.T, portName, portfile string) string {
	t.Helper()
	root := t.TempDir()
	mustMkdir(t, filepath.Join(root, "versions"))
	writeFile(t, filepath.Join(root, "versions", "baseline.json"), "{\"default\":{}}\n")
	createPortFixtureAt(t, filepath.Join(root, "ports"), portName, portfile)
	return root
}

func successfulPortfile() string {
	return `file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/share/${PORT}")
file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/copyright" "MIT")
`
}

func withWorkingDirectory(t *testing.T, path string, action func()) {
	t.Helper()
	previous, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(path); err != nil {
		t.Fatal(err)
	}
	defer func() {
		if err := os.Chdir(previous); err != nil {
			t.Errorf("restore working directory: %v", err)
		}
	}()
	action()
}

func testConfig(t *testing.T) *RuntimeConfig {
	t.Helper()
	root := t.TempDir()
	tools := make(map[string]string)
	for _, name := range []string{"vcpkg", "git", "cmake", "gh"} {
		if path, err := exec.LookPath(name); err == nil {
			tools[name] = path
		}
	}
	config := &RuntimeConfig{Workspace: root, WorkingDirectory: root, Scenario: "registry", Tools: tools, Roots: VcpkgRoots{Vcpkg: os.Getenv("VCPKG_ROOT"), Buildtrees: filepath.Join(root, "b"), Installed: filepath.Join(root, "i"), Packages: filepath.Join(root, "p")}, Scratch: filepath.Join(root, "scratch"), LogDirectory: filepath.Join(root, "logs"), OverlayPorts: []string{filepath.Join(root, "ports")}, OverlayTriplets: []string{filepath.Join(root, "triplets")}, WriteScopes: defaultWriteScopes("registry"), VcpkgEnv: scrubbedVcpkgEnvironment(os.Environ(), nil)}
	for _, directory := range []string{config.Scratch, config.LogDirectory, config.Roots.Buildtrees, config.Roots.Installed, config.Roots.Packages, config.OverlayPorts[0], config.OverlayTriplets[0]} {
		if err := os.MkdirAll(directory, 0755); err != nil {
			t.Fatal(err)
		}
	}
	return config
}

func TestAgentDefinitionsContainWorkToolsOnly(t *testing.T) {
	for _, agent := range agentDefinitions {
		for _, tool := range agent.Tools {
			if strings.Contains(tool, "_to_") {
				t.Errorf("%s exposes routing tool %q", agent.Name, tool)
			}
		}
	}
}
func TestStructuredHandoffExcludesSession(t *testing.T) {
	encoded, err := json.Marshal(Handoff{Session: &copilot.Session{SessionID: "shared-session"}, Goal: "continue", Evidence: []string{"verified"}})
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(encoded, []byte("shared-session")) {
		t.Fatalf("session leaked into structured result: %s", encoded)
	}
}

func TestStructuredResponseSchemaSelectsOneRoute(t *testing.T) {
	schema, err := structuredResponseSchema(map[string]any{plannerName: Handoff{}, tripletEditorName: Handoff{}})
	if err != nil {
		t.Fatal(err)
	}
	encoded, err := json.Marshal(schema)
	if err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{`"additionalProperties":false`, `"planner"`, `"triplet-editor"`, `"type":"null"`} {
		if !bytes.Contains(encoded, []byte(expected)) {
			t.Fatalf("schema lacks %s: %s", expected, encoded)
		}
	}
	if bytes.Contains(encoded, []byte(`"Session"`)) || bytes.Contains(encoded, []byte(`"session"`)) {
		t.Fatalf("session leaked into response schema: %s", encoded)
	}
}

func TestAgentCommunicationRoutes(t *testing.T) {
	want := []string{plannerName, environmentDetectorName, portInstallerName, portDoctorName, portEditorName, tripletEditorName, baselineUpdaterName}
	for index, agent := range agentDefinitions {
		if index >= len(want) || agent.Name != want[index] {
			t.Fatalf("agent %d = %q", index, agent.Name)
		}
	}
	if len(agentDefinitions) != len(want) {
		t.Fatalf("agent count = %d", len(agentDefinitions))
	}
}

func TestAgentChannelShutdown(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
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
	var wait sync.WaitGroup
	wait.Add(7)
	go (&Planner{}).Run(ctx, userRequests, environmentReports, installReports, blockers, reinstalls, baselineReports,
		detectRequests, installRequests, baselineRequests, final, errorsOut, &wait)
	go (&EnvironmentDetector{}).Run(ctx, detectRequests, hostRequests, environmentReports, hostFacts, errorsOut, &wait)
	go (&PortInstaller{}).Run(ctx, installRequests, retries, installFailures, installReports, errorsOut, &wait)
	go (&PortDoctor{}).Run(ctx, installFailures, portGoals, tripletGoals, blockers, errorsOut, &wait)
	go (&PortEditor{}).Run(ctx, portGoals, retries, errorsOut, &wait)
	go (&TripletEditor{}).Run(ctx, tripletGoals, hostFacts, hostRequests, reinstalls, errorsOut, &wait)
	go (&BaselineUpdater{}).Run(ctx, baselineRequests, baselineReports, errorsOut, &wait)
	cancel()
	finished := make(chan struct{})
	go func() { wait.Wait(); close(finished) }()
	select {
	case <-finished:
	case <-time.After(time.Second):
		t.Fatal("agents did not terminate after cancellation")
	}
	close(errorsOut)
	for err := range errorsOut {
		t.Errorf("unexpected error during shutdown: %v", err)
	}
}
func TestRoleFilePermissions(t *testing.T) {
	config := testConfig(t)
	message := Handoff{Ports: []string{"zlib"}, Triplet: "x64-windows"}
	portfile := filepath.Join(config.Workspace, "ports", "zlib", "portfile.cmake")
	for _, role := range []string{plannerName, environmentDetectorName, portInstallerName, portDoctorName} {
		if _, allowed := config.authorizeRequest(role, message, &rpc.PermissionRequestWrite{FileName: portfile}).(*rpc.PermissionDecisionApproveOnce); allowed {
			t.Errorf("%s gained write access", role)
		}
	}
	if _, allowed := config.authorizeRequest(portEditorName, message, &rpc.PermissionRequestWrite{FileName: portfile}).(*rpc.PermissionDecisionApproveOnce); !allowed {
		t.Fatal("target port is not writable")
	}
	other := filepath.Join(config.Workspace, "ports", "other", "portfile.cmake")
	if _, allowed := config.authorizeRequest(portEditorName, message, &rpc.PermissionRequestWrite{FileName: other}).(*rpc.PermissionDecisionApproveOnce); allowed {
		t.Fatal("another port is writable")
	}
	outside := filepath.Join(t.TempDir(), "secret.txt")
	if _, allowed := config.authorizeRequest(portDoctorName, message, &rpc.PermissionRequestRead{Path: outside}).(*rpc.PermissionDecisionApproveOnce); allowed {
		t.Fatal("outside read allowed")
	}
	config.DryRun = true
	if len(writePaths(config, portEditorName, message)) != 0 {
		t.Fatal("dry run grants file writes")
	}
}
func TestSessionPermissionPolicyUsesAgentTools(t *testing.T) {
	config := testConfig(t)
	message := Handoff{Goal: "Detect environment", Evidence: []string{"user"}}
	if _, ok := config.authorizeRequest(plannerName, message, &rpc.PermissionRequestCustomTool{ToolName: "execute_tool"}).(*rpc.PermissionDecisionApproveOnce); !ok {
		t.Fatal("planner command tool denied")
	}
	if _, ok := config.authorizeRequest(plannerName, message, &rpc.PermissionRequestCustomTool{ToolName: "apply_patch"}).(*rpc.PermissionDecisionReject); !ok {
		t.Fatal("planner gained an editor tool")
	}
	options := sessionOptions(config, Options{Model: defaultModel})
	if options.Hooks.Handlers == nil || options.Hooks.Handlers.OnPostToolUse == nil || options.Hooks.Handlers.OnPreToolUse != nil {
		t.Fatal("session hooks must only redact tool results")
	}
	if options.Permissions.OnRequest == nil {
		t.Fatal("manual permission policy missing")
	}
}

func TestCommandHarness(t *testing.T) {
	config := testConfig(t)
	config.Tools["gh"] = "gh"
	config.Tools["git"] = "git"
	config.Tools["vcpkg"] = "vcpkg"
	message := Handoff{Ports: []string{"zlib"}, Triplet: "x64-windows"}
	for _, test := range []struct {
		role    string
		params  commandParams
		allowed bool
	}{{plannerName, commandParams{Tool: "vcpkg", Args: []string{"help", "install"}}, true}, {plannerName, commandParams{Tool: "vcpkg", Args: []string{"install", "zlib"}}, false}, {portInstallerName, commandParams{Tool: "vcpkg", Args: []string{"install", "zlib:x64-windows", "--dry-run"}}, true}, {portDoctorName, commandParams{Tool: "git", Args: []string{"push"}}, false}, {portDoctorName, commandParams{Tool: "gh", Args: []string{"issue", "create"}}, false}, {portDoctorName, commandParams{Tool: "gh", Args: []string{"search", "issues", "error"}}, true}, {portInstallerName, commandParams{Tool: "vcpkg", Args: []string{"install", "--debug-env"}}, false}, {portInstallerName, commandParams{Tool: "vcpkg", Args: []string{"install", "--binarysource=clear"}}, false}, {portInstallerName, commandParams{Tool: "vcpkg", Args: []string{"install", "--x-install-root=C:/outside"}}, false}, {portEditorName, commandParams{Tool: "git", Args: []string{"diff", "--output=" + filepath.Join(t.TempDir(), "outside.patch")}}, false}, {portEditorName, commandParams{Tool: "git", Args: []string{"diff", "--output=" + filepath.Join(config.Workspace, "ports", "zlib", "fix.patch")}}, true}} {
		if _, err := test.params.validate(config, test.role, message); (err == nil) != test.allowed {
			t.Errorf("%s %v: %v, allowed=%t", test.role, test.params, err, test.allowed)
		}
	}
	config.DryRun = true
	if _, err := (commandParams{Tool: "vcpkg", Args: []string{"install", "zlib"}}).validate(config, portInstallerName, message); err == nil {
		t.Fatal("dry run permits real installation")
	}
	config.DryRun = false
	config.Scenario = "manifest"
	if _, err := (commandParams{Tool: "vcpkg", Args: []string{"remove", "zlib"}}).validate(config, portInstallerName, message); err == nil {
		t.Fatal("manifest removal allowed")
	}
}
func TestVcpkgOutputPreserved(t *testing.T) {
	config := testConfig(t)
	if config.Tools["vcpkg"] == "" {
		t.Skip("vcpkg executable required")
	}
	args := append([]string{"version"}, config.vcpkgArgs("", false)...)
	command := exec.Command(config.Tools["vcpkg"], args...)
	command.Dir = config.Workspace
	command.Env = config.VcpkgEnv
	want, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("vcpkg reference: %v\n%s", err, want)
	}
	result, err := executeTool(config, environmentDetectorName, Handoff{}, commandParams{Tool: "vcpkg", Args: []string{"version"}}, context.Background())
	if err != nil || result.ExitCode != 0 {
		t.Fatalf("command: %+v %v", result, err)
	}
	got, err := os.ReadFile(result.Log)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, want) {
		t.Fatalf("vcpkg output changed:\ngot %q\nwant %q", got, want)
	}
}
func TestCommandLogKeepsDiagnosticsAndRedactsSecrets(t *testing.T) {
	file, err := os.CreateTemp(t.TempDir(), "log-*")
	if err != nil {
		t.Fatal(err)
	}
	writer := &safeLogWriter{file: file, secrets: []string{"sensitive-value"}}
	text := "warning: original\r\nerror: original\nerror: original\ncredential=sensitive-value\n"
	if _, err := io.WriteString(writer, text); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(file.Name())
	if err != nil {
		t.Fatal(err)
	}
	want := "warning: original\r\nerror: original\nerror: original\ncredential=***SECRET***\n"
	if string(got) != want {
		t.Fatalf("log = %q", got)
	}
}
func TestCommitRequiresAuthority(t *testing.T) {
	config := testConfig(t)
	if config.Tools["git"] == "" {
		t.Skip("git executable required")
	}
	config.WriteScopes = map[string]bool{"ports": true}
	message := Handoff{Ports: []string{"zlib"}}
	params := commandParams{Tool: "git", Args: []string{"commit", "-m", "port update\n\n" + coauthorTrailer}}
	if _, err := params.validate(config, baselineUpdaterName, message); err == nil {
		t.Fatal("commit without authority allowed")
	}
	params.Args = []string{"add", "--", "ports/zlib"}
	if _, err := params.validate(config, baselineUpdaterName, message); err == nil {
		t.Fatal("staging without commit authority allowed")
	}
}

func TestProductionSourcePolicies(t *testing.T) {
	data, err := os.ReadFile("vcpkg-agents.go")
	if err != nil {
		t.Fatal(err)
	}
	for _, forbidden := range []string{
		"context.WithTimeout(", "context.WithTimeoutCause(", "context.WithDeadline(", "context.WithDeadlineCause(", ".SendAndWait(",
		"chan copilot.ToolInvocation", "(copilot.ToolInvocation, error)", "defer os.Exit", "type agentResult", "type responseWaiter", "type handoffTool", "type commandTool", "type crlfPortScanner",
		"func send[", "waitForResponse(", "Options Options", "EnableSandbox",
	} {
		if bytes.Contains(data, []byte(forbidden)) {
			t.Errorf("production source contains %q", forbidden)
		}
	}
	for _, agent := range agentDefinitions {
		if strings.Contains(agent.Prompt, "You are ") {
			t.Errorf("%s prompt repeats its role name", agent.Name)
		}
	}
}

func TestRolesRemainStateless(t *testing.T) {
	for name, role := range map[string]any{
		plannerName:             Planner{},
		environmentDetectorName: EnvironmentDetector{},
		portInstallerName:       PortInstaller{},
		portDoctorName:          PortDoctor{},
		portEditorName:          PortEditor{},
		tripletEditorName:       TripletEditor{},
		baselineUpdaterName:     BaselineUpdater{},
	} {
		if fields := reflect.TypeOf(role).NumField(); fields != 0 {
			t.Errorf("%s has %d fields, want 0", name, fields)
		}
	}
}
