package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io"
	"os"
	"os/exec"
	"path/filepath"
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
}
func TestLoadRuntimeConfigDetectsRegistryAndManifest(t *testing.T) {
	t.Run("registry", func(t *testing.T) {
		root := createRegistryFixture(t, "agent-config-ok", successfulPortfile())
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
			if !strings.Contains(blockers, "VCPKG_DEFAULT_TRIPLET is set but empty") || !strings.Contains(config.DetectionError, "Invalid triplet:") || !strings.Contains(config.DetectionError, "Built-in Triplets:") {
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
	return &RuntimeConfig{Options: Options{Model: defaultModel, MaxPortCycles: 3, MaxTripletEdits: 1, LockWait: 2 * time.Minute}, WorkingDirectory: workspace, Workspace: workspace, Scenario: scenario, ScenarioEvidence: []string{filepath.Join(workspace, "ports")}, Tools: tools, Roots: roots, OverlayPorts: []string{filepath.Join(workspace, "ports")}, OverlayTriplets: []string{filepath.Join(workspace, "triplets")}, DefaultTriplet: triplet, HostTriplet: triplet, VcpkgEnv: scrubbedVcpkgEnvironment(os.Environ(), nil), Scratch: scratch, LogDirectory: logs, WriteScopes: writeScopes, SecretValues: collectSecretValues(), RunID: "test"}
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
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	output, err := exec.CommandContext(ctx, vcpkg, "z-print-config", "--disable-metrics").Output()
	if err != nil {
		t.Fatalf("vcpkg z-print-config: %v", err)
	}
	var printed zPrintConfig
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
	config := &RuntimeConfig{Options: Options{Model: defaultModel, MaxPortCycles: 3, MaxTripletEdits: 1}, Workspace: root, WorkingDirectory: root, Scenario: "registry", Tools: tools, Roots: VcpkgRoots{Vcpkg: os.Getenv("VCPKG_ROOT"), Buildtrees: filepath.Join(root, "b"), Installed: filepath.Join(root, "i"), Packages: filepath.Join(root, "p")}, Scratch: filepath.Join(root, "scratch"), LogDirectory: filepath.Join(root, "logs"), OverlayPorts: []string{filepath.Join(root, "ports")}, OverlayTriplets: []string{filepath.Join(root, "triplets")}, WriteScopes: defaultWriteScopes("registry"), VcpkgEnv: scrubbedVcpkgEnvironment(os.Environ(), nil)}
	for _, directory := range []string{config.Scratch, config.LogDirectory, config.Roots.Buildtrees, config.Roots.Installed, config.Roots.Packages, config.OverlayPorts[0], config.OverlayTriplets[0]} {
		if err := os.MkdirAll(directory, 0755); err != nil {
			t.Fatal(err)
		}
	}
	return config
}

func TestHandoffWaitsForSender(t *testing.T) {
	name := plannerName
	activeAgent.Store(&name)
	t.Cleanup(func() {
		activeAgent.Store(nil)
	})
	pending := make(chan copilot.ToolInvocation, 1)
	output := make(chan Handoff, 1)
	session := &copilot.Session{SessionID: "same-session"}
	tool := goalTool("send_detect_request", session, pending)
	message := Handoff{Goal: "Verify target availability", Evidence: []string{"user request"}}
	if !tool.IsTerminal {
		t.Fatal("handoff tool must be terminal")
	}
	if _, err := tool.Handler(copilot.ToolInvocation{Arguments: message}); err != nil {
		t.Fatal(err)
	}
	select {
	case <-output:
		t.Fatal("tool sent before the goroutine could compact")
	default:
	}
	if _, err := tool.Handler(copilot.ToolInvocation{Arguments: message}); err == nil {
		t.Fatal("duplicate handoff accepted")
	}
	next := <-pending
	if next.ToolName != "send_detect_request" {
		t.Fatal("selected SDK tool changed")
	}
	if err := send(context.Background(), output, next.Arguments.(Handoff)); err != nil {
		t.Fatal(err)
	}
	got := <-output
	if got.Session != session || got.Goal != message.Goal {
		t.Fatalf("handoff = %+v", got)
	}
}
func TestPlannerFinalReportWaitsForSender(t *testing.T) {
	output := make(chan FinalReport, 1)
	planner := NewPlanner(&copilot.Session{SessionID: "shared-session"})
	report := FinalReport{Status: "finished", Scenario: "registry"}
	if _, err := planner.finish(report, copilot.ToolInvocation{}); err != nil {
		t.Fatal(err)
	}
	if len(output) != 0 {
		t.Fatal("final report sent before compaction")
	}
	if _, err := planner.finish(report, copilot.ToolInvocation{}); err == nil {
		t.Fatal("duplicate final report accepted")
	}
	next := <-planner.pending
	if next.ToolName != "send_final_report" {
		t.Fatal("queued final report tool missing")
	}
	if err := send(context.Background(), output, next.Arguments.(FinalReport)); err != nil {
		t.Fatal(err)
	}
	if got := <-output; got.Status != report.Status || got.Scenario != report.Scenario {
		t.Fatalf("final report = %+v", got)
	}
}

func TestAgentCommunicationRoutes(t *testing.T) {
	session := &copilot.Session{SessionID: "shared-session"}
	routes := make(map[string]chan Handoff)
	for _, name := range []string{
		"send_detect_request", "send_install_requests", "send_baseline_request",
		"send_env_report", "send_host_facts", "send_install_failure", "send_install_report",
		"send_port_goals", "send_triplet_goals", "send_blocker", "send_retry_request",
		"send_host_facts_request", "send_reinstall_request", "send_baseline_report",
	} {
		routes[name] = make(chan Handoff, 1)
	}
	planner := NewPlanner(session)
	detector := NewEnvironmentDetector(session)
	installer := NewPortInstaller(session)
	doctor := NewPortDoctor(session)
	editor := NewPortEditor(session)
	triplet := NewTripletEditor(session)
	baseline := NewBaselineUpdater(session)
	t.Cleanup(func() { activeAgent.Store(nil) })
	for _, actor := range []struct {
		name    string
		tools   []copilot.Tool
		pending <-chan copilot.ToolInvocation
	}{
		{plannerName, planner.tools, planner.pending},
		{environmentDetectorName, detector.tools, detector.pending},
		{portInstallerName, installer.tools, installer.pending},
		{portDoctorName, doctor.tools, doctor.pending},
		{portEditorName, editor.tools, editor.pending},
		{tripletEditorName, triplet.tools, triplet.pending},
		{baselineUpdaterName, baseline.tools, baseline.pending},
	} {
		activeAgent.Store(&actor.name)
		for _, tool := range actor.tools {
			if tool.Name == "send_final_report" {
				continue
			}
			t.Run(actor.name+"/"+tool.Name, func(t *testing.T) {
				message := Handoff{Goal: "achieve the received goal", Evidence: []string{"unchanged evidence"}}
				if _, err := tool.Handler(copilot.ToolInvocation{Arguments: message}); err != nil {
					t.Fatal(err)
				}
				next := <-actor.pending
				handoff := next.Arguments.(Handoff)
				if next.ToolName != tool.Name || handoff.Session != session || handoff.Goal != message.Goal {
					t.Fatalf("incorrect handoff: %+v", next)
				}
				if len(routes[tool.Name]) != 0 {
					t.Fatal("receiver notified before sender compaction")
				}
				if err := send(context.Background(), routes[next.ToolName], handoff); err != nil {
					t.Fatal(err)
				}
				if got := <-routes[tool.Name]; !slices.Equal(got.Evidence, message.Evidence) {
					t.Fatal("handoff evidence changed")
				}
			})
		}
	}
}

func TestAgentChannelShutdown(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	session := &copilot.Session{SessionID: "shared-session"}
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
	go NewPlanner(session).Run(ctx, userRequests, environmentReports, installReports, blockers, reinstalls, baselineReports,
		detectRequests, installRequests, baselineRequests, final, errorsOut, &wait)
	go NewEnvironmentDetector(session).Run(ctx, detectRequests, hostRequests, environmentReports, hostFacts, errorsOut, &wait)
	go NewPortInstaller(session).Run(ctx, installRequests, retries, installFailures, installReports, errorsOut, &wait)
	go NewPortDoctor(session).Run(ctx, installFailures, portGoals, tripletGoals, blockers, errorsOut, &wait)
	go NewPortEditor(session).Run(ctx, portGoals, retries, errorsOut, &wait)
	go NewTripletEditor(session).Run(ctx, tripletGoals, hostFacts, hostRequests, reinstalls, errorsOut, &wait)
	go NewBaselineUpdater(session).Run(ctx, baselineRequests, baselineReports, errorsOut, &wait)
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
		if _, allowed := permission(config, role, message, &rpc.PermissionRequestWrite{FileName: portfile}).(*rpc.PermissionDecisionApproveOnce); allowed {
			t.Errorf("%s gained write access", role)
		}
	}
	if _, allowed := permission(config, portEditorName, message, &rpc.PermissionRequestWrite{FileName: portfile}).(*rpc.PermissionDecisionApproveOnce); !allowed {
		t.Fatal("target port is not writable")
	}
	other := filepath.Join(config.Workspace, "ports", "other", "portfile.cmake")
	if _, allowed := permission(config, portEditorName, message, &rpc.PermissionRequestWrite{FileName: other}).(*rpc.PermissionDecisionApproveOnce); allowed {
		t.Fatal("another port is writable")
	}
	outside := filepath.Join(t.TempDir(), "secret.txt")
	if _, allowed := permission(config, portDoctorName, message, &rpc.PermissionRequestRead{Path: outside}).(*rpc.PermissionDecisionApproveOnce); allowed {
		t.Fatal("outside read allowed")
	}
	config.Options.Prompt = "dry run install zlib"
	if len(writePaths(config, portEditorName, message)) != 0 {
		t.Fatal("dry run grants file writes")
	}
}
func TestAllowedHookUsesNormalPermission(t *testing.T) {
	config := testConfig(t)
	name := plannerName
	message := Handoff{Goal: "Detect environment", Evidence: []string{"user"}}
	activeAgent.Store(&name)
	activeMessage.Store(&message)
	t.Cleanup(func() { activeAgent.Store(nil); activeMessage.Store(nil) })
	result, err := hooks(config).OnPreToolUse(copilot.PreToolUseHookInput{ToolName: "send_detect_request"}, copilot.HookInvocation{})
	if err != nil || result != nil {
		t.Fatalf("allowed hook must defer to normal permission: %+v %v", result, err)
	}
	if _, ok := permission(config, name, message, &rpc.PermissionRequestCustomTool{ToolName: "send_detect_request"}).(*rpc.PermissionDecisionApproveOnce); !ok {
		t.Fatal("handoff denied by normal permission")
	}
	result, err = hooks(config).OnPreToolUse(copilot.PreToolUseHookInput{ToolName: "apply_patch"}, copilot.HookInvocation{})
	if err != nil || result == nil || result.PermissionDecision != "deny" {
		t.Fatalf("planner write hook = %+v %v", result, err)
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
		if err := checkCommand(config, test.role, message, test.params); (err == nil) != test.allowed {
			t.Errorf("%s %v: %v, allowed=%t", test.role, test.params, err, test.allowed)
		}
	}
	config.Options.Prompt = "dry run install zlib"
	if err := checkCommand(config, portInstallerName, message, commandParams{Tool: "vcpkg", Args: []string{"install", "zlib"}}); err == nil {
		t.Fatal("dry run permits real installation")
	}
	config.Options.Prompt = "install this manifest"
	config.Scenario = "manifest"
	if err := checkCommand(config, portInstallerName, message, commandParams{Tool: "vcpkg", Args: []string{"remove", "zlib"}}); err == nil {
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
	if err := checkCommand(config, baselineUpdaterName, message, params); err == nil {
		t.Fatal("commit without authority allowed")
	}
	params.Args = []string{"add", "--", "ports/zlib"}
	if err := checkCommand(config, baselineUpdaterName, message, params); err == nil {
		t.Fatal("staging without commit authority allowed")
	}
}
