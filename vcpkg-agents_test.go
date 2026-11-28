package main

import (
	"context"
	"crypto/sha512"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"testing"
	"time"

	copilot "github.com/microsoft/copilot-sdk/go/v2"
	"github.com/microsoft/copilot-sdk/go/v2/rpc"
)

func TestParseOptionsDefaultModelAndScopes(t *testing.T) {
	options, err := ParseOptions([]string{"--prompt", "Dry run zlib-ng"})
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
		withWorkingDirectory(t, root, func() {
			options, err := ParseOptions([]string{
				"--prompt", "Dry run agent-config-ok",
				"--overlay-ports", filepath.Join(root, "ports"),
				"--x-buildtrees-root", filepath.Join(root, "buildtrees"),
				"--x-packages-root", filepath.Join(root, "packages"),
				"--x-install-root", filepath.Join(root, "installed"),
			})
			if err != nil {
				t.Fatal(err)
			}
			config, err := LoadRuntimeConfig(options)
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { _ = config.Cleanup() })
			if config.Scenario != "registry" {
				t.Fatalf("scenario = %q", config.Scenario)
			}
			if !containsPath(config.OverlayPorts, filepath.Join(root, "ports")) {
				t.Fatalf("registry ports overlay missing: %v", config.OverlayPorts)
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
			t.Cleanup(func() { _ = config.Cleanup() })
			if config.Scenario != "manifest" || !samePath(config.ManifestRoot, root) {
				t.Fatalf("manifest detection = %q, %q", config.Scenario, config.ManifestRoot)
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
			t.Cleanup(func() { _ = config.Cleanup() })
			joined := strings.Join(config.Blockers, "\n")
			if !strings.Contains(joined, "core.autocrlf") || !strings.Contains(joined, "CRLF") {
				t.Fatalf("version precondition blockers = %v", config.Blockers)
			}
		})
	})
}

func TestSevenMemberDefinitionsAndSingleModel(t *testing.T) {
	config := newTestRuntimeConfig(t, "registry")
	team := NewTeam(config)
	options := team.sessionOptions()
	if options.Model != defaultModel {
		t.Fatalf("session model = %q", options.Model)
	}
	if len(options.Agents.Definitions) != 7 {
		t.Fatalf("agents = %d, want 7", len(options.Agents.Definitions))
	}
	names := make([]string, 0, 7)
	for _, agent := range options.Agents.Definitions {
		names = append(names, agent.Name)
		if agent.Infer == nil || *agent.Infer {
			t.Errorf("%s may be model-inferred", agent.Name)
		}
	}
	want := []string{plannerName, environmentDetectorName, portInstallerName, portDoctorName, portEditorName, tripletEditorName, baselineUpdaterName}
	if !slices.Equal(names, want) {
		t.Fatalf("agent order = %v, want %v", names, want)
	}
	for _, tool := range team.tools {
		if tool.SkipPermission {
			t.Fatalf("tool %s skips permission", tool.Name)
		}
	}
	if len(team.planner.Scope().Write) != 0 || len(team.installer.Scope().Write) != 0 ||
		len(team.doctor.Scope().Write) != 0 {
		t.Fatal("read-only members received write scope")
	}
	if len(team.editor.Scope().Write) == 0 || len(team.baseline.Scope().Write) == 0 {
		t.Fatal("writer member has no write scope")
	}
}

func TestPlannerBuildsOrderedRegistryRequests(t *testing.T) {
	config := newTestRuntimeConfig(t, "registry")
	createPortFixture(t, filepath.Join(config.Workspace, "ports"), "agent-plan-ok")
	config.OverlayPorts = append([]string{filepath.Join(config.Workspace, "ports")}, config.OverlayPorts...)
	team := NewTeam(config)
	team.planner.userPrompt = "Dry run agent-plan-ok for x64-windows and arm64-windows."
	environment := EnvReport{
		Scenario: "registry", ScenarioEvidence: []string{filepath.Join(config.Workspace, "ports")},
		Triplets:  []TripletFile{{Name: "x64-windows"}, {Name: "arm64-windows"}},
		PortsHint: []string{"agent-plan-ok"}, DryRunOnly: true,
	}
	requests := team.planner.buildInstallRequests(environment)
	if len(requests) != 2 {
		t.Fatalf("requests = %d", len(requests))
	}
	if requests[0].Triplet != "x64-windows" || requests[1].Triplet != "arm64-windows" {
		t.Fatalf("order = %v, %v", requests[0].Triplet, requests[1].Triplet)
	}
	if !requests[0].DryRunOnly || requests[0].Final || !requests[1].Final {
		t.Fatalf("dry-run/final flags = %+v, %+v", requests[0], requests[1])
	}
	if !slices.Equal(requests[0].Ports, []string{"agent-plan-ok"}) {
		t.Fatalf("ports = %v", requests[0].Ports)
	}
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
	if !strings.Contains(joined, "VCPKG_FEATURE_FLAGS=-dependencygraph,registries") &&
		!strings.Contains(joined, "VCPKG_FEATURE_FLAGS=registries,-dependencygraph") {
		t.Fatalf("dependencygraph was not disabled: %s", joined)
	}
	redacted := redactText("on expression: files,/secret?sig=secret-value", collectSecretValues())
	if strings.Contains(redacted, "secret-value") {
		t.Fatal("known secret remained after redaction")
	}
}

func TestPortInstallerRealDryRunAndFailure(t *testing.T) {
	config := newTestRuntimeConfig(t, "registry")
	overlay := filepath.Join(config.Workspace, "ports")
	createPortFixture(t, overlay, "agent-install-ok")
	config.OverlayPorts = []string{overlay}
	team := NewTeam(config)
	t.Cleanup(func() { _ = config.Cleanup() })

	request := InstallRequest{
		Triplet: "x64-windows", Ports: []string{"agent-install-ok"}, Reason: "test", DryRunOnly: true,
	}
	failure, result, ok := team.performInstall(context.Background(), request)
	if !ok {
		t.Fatalf("dry run failed: %+v", failure)
	}
	if result.Stage != "dry-run" || !result.Installed {
		t.Fatalf("result = %+v", result)
	}
	list, listErr := team.listStage(context.Background(), request)
	if listErr != nil || list.Err != nil {
		t.Fatalf("list after dry run: %v / %v", listErr, list.Err)
	}
	if anyPortInstalled(list.Summary, request.Ports) {
		t.Fatalf("dry run installed the port:\n%s", list.Summary)
	}

	unknown := request
	unknown.Ports = []string{"port-that-does-not-exist-agent-test"}
	failure, _, ok = team.performInstall(context.Background(), unknown)
	if ok || failure.Stage != "dry-run" || failure.ExitCode == 0 {
		t.Fatalf("unknown port result = %+v, ok=%v", failure, ok)
	}
	if !fileExists(failure.OutputLog) {
		t.Fatalf("failure log missing: %s", failure.OutputLog)
	}
}

func TestPortInstallerSplitsBatchAndUnblocksTripletReinstall(t *testing.T) {
	installer := NewPortInstaller(newTestRuntimeConfig(t, "registry"))
	installer.stack = []InstallRequest{{Triplet: "x64-windows", Ports: []string{"failed"}}}
	installer.waiting = true
	installer.enqueue(InstallRequest{
		Triplet: "x64-windows", Ports: []string{"first", "second"}, Reason: "reinstall", Final: true,
	})
	if installer.waiting {
		t.Fatal("reinstall did not clear installer wait")
	}
	if len(installer.stack) != 2 || !slices.Equal(installer.stack[0].Ports, []string{"first"}) ||
		!slices.Equal(installer.stack[1].Ports, []string{"second"}) {
		t.Fatalf("reinstall stack = %+v", installer.stack)
	}
	if installer.stack[0].Final || !installer.stack[1].Final {
		t.Fatalf("split final flags = %+v", installer.stack)
	}
}

func TestPortInstallerRealInstallAndRemove(t *testing.T) {
	if testing.Short() {
		t.Skip("vcpkg full install")
	}
	config := newTestRuntimeConfig(t, "registry")
	overlay := filepath.Join(config.Workspace, "ports")
	createPortFixture(t, overlay, "agent-install-full")
	config.OverlayPorts = []string{overlay}
	team := NewTeam(config)

	request := InstallRequest{Triplet: "x64-windows", Ports: []string{"agent-install-full"}, Reason: "test"}
	failure, result, ok := team.performInstall(context.Background(), request)
	if !ok {
		t.Fatalf("install failed: %+v", failure)
	}
	if result.Stage != "build" || !result.Installed {
		t.Fatalf("result = %+v", result)
	}
	installed := filepath.Join(config.Roots.Installed, "vcpkg", "status")
	if !fileExists(installed) {
		t.Fatalf("vcpkg status missing at %s", installed)
	}
	removed, err := team.removeStage(context.Background(), request)
	if err != nil || removed.Err != nil {
		t.Fatalf("remove failed: %s: %v", removed.modelText(err), removed.Err)
	}
}

func TestPortInstallerManifestDryRunDoesNotRemove(t *testing.T) {
	config := newTestRuntimeConfig(t, "manifest")
	config.ManifestRoot = config.Workspace
	writeFile(t, filepath.Join(config.Workspace, "vcpkg.json"),
		`{"name":"agent-manifest-test","version-string":"1.0.0","dependencies":[]}`)
	team := NewTeam(config)
	request := InstallRequest{
		Triplet: config.DefaultTriplet, ManifestRoot: config.ManifestRoot,
		Reason: "manifest dry run", DryRunOnly: true,
	}
	failure, result, ok := team.performInstall(context.Background(), request)
	if !ok {
		t.Fatalf("manifest dry run failed: %+v", failure)
	}
	if result.Stage != "dry-run" || result.Spec != "manifest" {
		t.Fatalf("manifest result = %+v", result)
	}
	team.active.Store(team.installer.Member)
	_, err := invokeTool(team, "vcpkg_remove", vcpkgInstallParams{
		Triplet: config.DefaultTriplet, Ports: []string{"agent-manifest-test"},
	})
	if err == nil || !strings.Contains(err.Error(), "forbidden in manifest") {
		t.Fatalf("manifest remove error = %v", err)
	}
}

func TestPortInstallerDetectsUnsupportedTargetAfterDryRun(t *testing.T) {
	if runtime.GOOS != "windows" {
		t.Skip("the fixture relies on the documented Windows-to-macOS compiler failure")
	}
	config := newTestRuntimeConfig(t, "registry")
	overlay := filepath.Join(config.Workspace, "ports")
	createPortFixture(t, overlay, "agent-target-ok")
	config.OverlayPorts = []string{overlay}
	team := NewTeam(config)
	failure, _, ok := team.performInstall(context.Background(), InstallRequest{
		Triplet: "arm64-osx", Ports: []string{"agent-target-ok"}, Reason: "unsupported target",
	})
	if ok {
		t.Fatal("arm64-osx unexpectedly installed on Windows")
	}
	if failure.Stage != "only-downloads" || !strings.Contains(failure.ResultCode, "COMPILER") {
		t.Fatalf("unsupported-target failure = %+v", failure)
	}
}

func TestPortDoctorClassifiesRealFailureEvidence(t *testing.T) {
	config := newTestRuntimeConfig(t, "registry")
	doctor := NewPortDoctor(config)
	failure := InstallFailure{
		Spec: "agent-patch", Triplet: "x64-windows", Stage: "build", ResultCode: "PATCH_FAILED",
		OutputLog: filepath.Join(config.LogDirectory, "failure.log"),
		ErrorLogs: []string{filepath.Join(config.Roots.Buildtrees, "agent-patch", "patch-x64-windows-0-err.log")},
	}
	if axis := diagnosisAxis(failure); axis != "source or port patch" {
		t.Fatalf("axis = %q", axis)
	}
	prompt := doctor.prompt(failure)
	for _, text := range []string{"send_port_goals", "send_triplet_goals", "send_blocker", "Deterministic axis hint"} {
		if !strings.Contains(prompt, text) {
			t.Fatalf("doctor prompt misses %q", text)
		}
	}
	if len(doctor.Scope().Write) != 0 {
		t.Fatal("Port Doctor is writable")
	}
}

func TestPortEditorRealPatchWorkflow(t *testing.T) {
	config := newTestRuntimeConfig(t, "registry")
	team := NewTeam(config)
	portRoot := createPortFixture(t, filepath.Join(config.Workspace, "ports"), "agent-patch-real")
	source := filepath.Join(config.Roots.Buildtrees, "agent-patch-real", "src", "source.clean")
	writeFile(t, filepath.Join(source, "hello.txt"), "before\n")
	scope := team.editor.Scope()
	scope.Write = append(scope.Write, portRoot)
	team.editor.setScope(scope)
	team.active.Store(team.editor.Member)
	t.Cleanup(func() { team.active.Store(nil) })

	prepare, err := invokeTool(team, "prepare_patch", preparePatchParams{Port: "agent-patch-real", SourceDir: source})
	if err != nil {
		t.Fatal(err)
	}
	scratch := strings.TrimSpace(prepare.TextResultForLLM)
	writeFile(t, filepath.Join(scratch, "hello.txt"), "after\n")
	result, err := invokeTool(team, "make_patch", makePatchParams{
		Port: "agent-patch-real", Scratch: scratch, SourceDir: source, Name: "fix-greeting", Header: "Fix greeting from the verified source.",
	})
	if err != nil {
		t.Fatal(err)
	}
	patch := strings.TrimSpace(result.TextResultForLLM)
	if !fileExists(patch) {
		t.Fatalf("patch missing: %s", patch)
	}
	content := readFile(t, patch)
	for _, text := range []string{"Fix greeting from the verified source.", "-before", "+after"} {
		if !strings.Contains(content, text) {
			t.Fatalf("patch misses %q:\n%s", text, content)
		}
	}
	if fileExists(filepath.Join(source, "hello.txt")) && readFile(t, filepath.Join(source, "hello.txt")) != "before\n" {
		t.Fatal("source tree was modified")
	}
	if _, err := os.Stat(scratch); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("scratch not removed: %v", err)
	}
}

func TestTripletEditorScopeUsesOverlayNotBuiltin(t *testing.T) {
	config := newTestRuntimeConfig(t, "registry")
	overlay := filepath.Join(config.Workspace, "triplets")
	mustMkdir(t, overlay)
	config.OverlayTriplets = []string{overlay}
	team := NewTeam(config)
	builtin := filepath.Join(config.Roots.Vcpkg, "triplets", config.DefaultTriplet+".cmake")
	goals := TripletGoals{Triplet: config.DefaultTriplet, TripletFile: builtin, OverlayRoot: overlay}
	scope := team.doctor.tripletScope(goals)
	if insideAny(builtin, scope.Write) {
		t.Fatal("built-in triplet entered Triplet Editor write scope")
	}
	overlayFile := filepath.Join(overlay, config.DefaultTriplet+".cmake")
	if !insideAny(overlayFile, scope.Write) {
		t.Fatal("overlay triplet is not writable")
	}
	team.triplet.setScope(scope)
	team.active.Store(team.triplet.Member)
	tool := findTool(t, team, "send_reinstall_request")
	_, err := tool.Handler(copilot.ToolInvocation{
		ToolName: tool.Name, Arguments: ReinstallRequest{
			Handoff: validHandoff(), Triplet: config.DefaultTriplet, TripletFile: overlayFile, Ports: []string{"x"},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	<-team.triplet.out

	team.triplet.edits[config.DefaultTriplet] = config.Options.MaxTripletEdits
	blocked, exhausted := team.triplet.tripletEditLimit(TripletGoals{
		Triplet: config.DefaultTriplet, TripletFile: overlayFile,
	})
	if !exhausted || !blocked.Blocked || !strings.Contains(blocked.Reason, "limit") {
		t.Fatalf("triplet edit limit = %+v, %v", blocked, exhausted)
	}
}

func TestBaselineUpdaterRealCommitsAndIndexGuard(t *testing.T) {
	config := newTestRuntimeConfig(t, "registry")
	team := NewTeam(config)
	initGitRepository(t, config.Workspace)
	port := filepath.Join(config.Workspace, "ports", "agent-commit-ok")
	versions := filepath.Join(config.Workspace, "versions")
	writeFile(t, filepath.Join(port, "vcpkg.json"), `{"name":"agent-commit-ok","version":"1.0.0"}`)
	writeFile(t, filepath.Join(versions, "baseline.json"), "{\"default\":{}}\n")
	runGitForTest(t, config.Workspace, "add", "-A")
	runGitForTest(t, config.Workspace, "commit", "-m", "test baseline")

	writeFile(t, filepath.Join(port, "new.txt"), "new\n")
	scope := team.baseline.Scope()
	scope.Write = append(scope.Write, port, versions)
	team.baseline.setScope(scope)
	team.active.Store(team.baseline.Member)
	t.Cleanup(func() { team.active.Store(nil) })
	result, err := invokeTool(team, "git_commit", gitCommitParams{
		Paths: []string{filepath.Join("ports", "agent-commit-ok")}, Message: "agent: update port",
	})
	if err != nil {
		t.Fatal(err)
	}
	hash := strings.Fields(result.TextResultForLLM)[0]
	if len(hash) < 7 {
		t.Fatalf("commit hash missing: %q", result.TextResultForLLM)
	}
	message := runGitForTest(t, config.Workspace, "show", "-s", "--format=%B", hash)
	if !strings.Contains(message, coauthorTrailer) {
		t.Fatalf("commit missing Co-authored-by:\n%s", message)
	}

	portTree := runGitForTest(t, config.Workspace, "rev-parse", hash+":"+filepath.ToSlash(filepath.Join("ports", "agent-commit-ok")))
	writeFile(t, filepath.Join(versions, "a-", "agent-commit-ok.json"),
		fmt.Sprintf(`{"versions":[{"git-tree":%q,"version":"1.0.0","port-version":0}]}`, portTree))
	versionCommit, err := invokeTool(team, "git_commit", gitCommitParams{
		Paths: []string{"versions"}, Message: "agent: update versions",
	})
	if err != nil {
		t.Fatal(err)
	}
	versionHash := strings.Fields(versionCommit.TextResultForLLM)[0]
	if err := team.validateBaselineReport(
		BaselineRequest{Ports: []string{"agent-commit-ok"}},
		BaselineReport{Commits: []Commit{
			{Hash: hash, Paths: []string{filepath.Join("ports", "agent-commit-ok")}},
			{Hash: versionHash, Paths: []string{"versions"}},
		}},
	); err != nil {
		t.Fatal(err)
	}

	userEdit := filepath.Join(port, "user-existing.txt")
	writeFile(t, userEdit, "user work\n")
	config.InitialDirty = []string{userEdit}
	_, err = invokeTool(team, "git_commit", gitCommitParams{
		Paths: []string{filepath.Join("ports", "agent-commit-ok")}, Message: "must preserve initial user work",
	})
	if err == nil || !strings.Contains(err.Error(), "before this run") {
		t.Fatalf("initial dirty work error = %v", err)
	}
	config.InitialDirty = nil
	_ = os.Remove(userEdit)

	writeFile(t, filepath.Join(port, "later.txt"), "later\n")
	unrelated := filepath.Join(config.Workspace, "outside.txt")
	writeFile(t, unrelated, "outside\n")
	runGitForTest(t, config.Workspace, "add", "outside.txt")
	_, err = invokeTool(team, "git_commit", gitCommitParams{
		Paths: []string{filepath.Join("ports", "agent-commit-ok")}, Message: "must reject staged user work",
	})
	if err == nil || !strings.Contains(err.Error(), "staged changes") {
		t.Fatalf("staged index error = %v", err)
	}
}

func TestBaselineVersionUpdateRealVcpkg(t *testing.T) {
	if testing.Short() {
		t.Skip("vcpkg x-add-version")
	}
	config := newTestRuntimeConfig(t, "registry")
	team := NewTeam(config)
	port := createPortFixture(t, filepath.Join(config.Workspace, "ports"), "agent-version-real")
	versions := filepath.Join(config.Workspace, "versions")
	writeFile(t, filepath.Join(versions, "baseline.json"), "{\"default\":{}}\n")
	initGitRepository(t, config.Workspace)
	runGitForTest(t, config.Workspace, "add", "-A")
	runGitForTest(t, config.Workspace, "commit", "-m", "registry baseline")

	scope := team.baseline.Scope()
	scope.Write = append(scope.Write, port, versions)
	team.baseline.setScope(scope)
	team.active.Store(team.baseline.Member)
	t.Cleanup(func() { team.active.Store(nil) })
	result, err := invokeTool(team, "version_update", versionUpdateParams{Port: "agent-version-real", Stage: "format"})
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(result.TextResultForLLM, "exit=1") {
		t.Fatalf("format failed:\n%s", result.TextResultForLLM)
	}
	commit, err := invokeTool(team, "git_commit", gitCommitParams{
		Paths: []string{filepath.Join("ports", "agent-version-real")}, Message: "agent: format port",
	})
	if err != nil {
		t.Fatal(err)
	}
	if commit.TextResultForLLM == "" {
		t.Fatal("port commit returned no result")
	}
	result, err = invokeTool(team, "version_update", versionUpdateParams{Port: "agent-version-real", Stage: "versions"})
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(result.TextResultForLLM, "exit=1") {
		t.Fatalf("version update failed:\n%s", result.TextResultForLLM)
	}
	baseline := readFile(t, filepath.Join(versions, "baseline.json"))
	if !strings.Contains(baseline, `"agent-version-real"`) || !strings.Contains(baseline, `"baseline": "1.0.0"`) {
		t.Fatalf("baseline was not updated:\n%s", baseline)
	}
	recordPath := versionRecordPath(config.Workspace, "agent-version-real")
	record := readFile(t, recordPath)
	if !strings.Contains(record, `"git-tree"`) {
		t.Fatalf("version record lacks git-tree:\n%s", record)
	}
}

func TestHooksDenyOutsideScopeAndApproveReadOnlyShell(t *testing.T) {
	config := newTestRuntimeConfig(t, "registry")
	team := NewTeam(config)
	team.active.Store(team.doctor.Member)
	t.Cleanup(func() { team.active.Store(nil) })

	allowed, err := team.preToolUse(copilot.PreToolUseHookInput{
		ToolName: "bash", WorkingDirectory: config.Workspace,
	}, copilot.HookInvocation{})
	if err != nil || allowed.PermissionDecision != "ask" {
		t.Fatalf("pre-hook allow = %+v, %v", allowed, err)
	}
	denied, err := team.preToolUse(copilot.PreToolUseHookInput{
		ToolName: "bash", WorkingDirectory: filepath.Join(t.TempDir(), "outside"),
	}, copilot.HookInvocation{})
	if err != nil || denied.PermissionDecision != "deny" {
		t.Fatalf("outside cwd = %+v, %v", denied, err)
	}

	request := &rpc.PermissionRequestShell{
		Commands:        []rpc.PermissionRequestShellCommand{{Identifier: "git", ReadOnly: true}},
		CommandSegments: []rpc.PermissionRequestShellCommandSegment{{Identifier: "git", FullCommandText: "git log --oneline"}},
		PossiblePaths:   []string{config.Workspace},
	}
	decision, err := team.permission(request, copilot.PermissionInvocation{})
	assertApproved(t, decision, err)

	request.Commands[0].ReadOnly = false
	decision, err = team.permission(request, copilot.PermissionInvocation{})
	assertRejected(t, decision, err, "read-only")

	request.Commands[0].ReadOnly = true
	request.CommandSegments[0].FullCommandText = "git push"
	decision, err = team.permission(request, copilot.PermissionInvocation{})
	assertRejected(t, decision, err, "not allowed")
}

func TestHooksEnforceReadWriteURLAndCustomToolPolicy(t *testing.T) {
	config := newTestRuntimeConfig(t, "registry")
	team := NewTeam(config)
	editorScope := team.editor.Scope()
	portRoot := filepath.Join(config.Workspace, "ports", "only-port")
	mustMkdir(t, portRoot)
	editorScope.Write = append(editorScope.Write, portRoot)
	team.editor.setScope(editorScope)
	team.active.Store(team.editor.Member)

	decision, err := team.permission(&rpc.PermissionRequestRead{Path: filepath.Join(config.Workspace, "docs", "x.md")}, copilot.PermissionInvocation{})
	assertApproved(t, decision, err)
	decision, err = team.permission(&rpc.PermissionRequestRead{Path: filepath.Join(t.TempDir(), "outside")}, copilot.PermissionInvocation{})
	assertRejected(t, decision, err, "read outside")
	decision, err = team.permission(&rpc.PermissionRequestWrite{FileName: filepath.Join(portRoot, "portfile.cmake")}, copilot.PermissionInvocation{})
	assertApproved(t, decision, err)
	decision, err = team.permission(&rpc.PermissionRequestWrite{FileName: filepath.Join(config.Workspace, "ports", "other", "portfile.cmake")}, copilot.PermissionInvocation{})
	assertRejected(t, decision, err, "write outside")
	decision, err = team.permission(&rpc.PermissionRequestURL{URL: "http://example.invalid/secret"}, copilot.PermissionInvocation{})
	assertRejected(t, decision, err, "URL outside")
	decision, err = team.permission(&rpc.PermissionRequestCustomTool{ToolName: "send_retry_request"}, copilot.PermissionInvocation{})
	assertApproved(t, decision, err)
	decision, err = team.permission(rpc.PermissionRequestCustomTool{ToolName: "send_retry_request"}, copilot.PermissionInvocation{})
	assertApproved(t, decision, err)
	decision, err = team.permission(&rpc.PermissionRequestCustomTool{ToolName: "git_commit"}, copilot.PermissionInvocation{})
	assertRejected(t, decision, err, "cannot use")
}

func TestPostHooksRedactSecretsAndGuideArgumentRepair(t *testing.T) {
	config := newTestRuntimeConfig(t, "registry")
	config.SecretValues = append(config.SecretValues, "token-never-print-this")
	team := NewTeam(config)
	output, err := team.postToolUse(copilot.PostToolUseHookInput{
		ToolResult: map[string]any{"text": "token-never-print-this"},
	}, copilot.HookInvocation{})
	if err != nil {
		t.Fatal(err)
	}
	encoded, _ := json.Marshal(output.ModifiedResult)
	if strings.Contains(string(encoded), "token-never-print-this") {
		t.Fatalf("secret remains: %s", encoded)
	}
	failure, err := team.postToolUseFailure(copilot.PostToolUseFailureHookInput{
		ToolName: "vcpkg_install", Error: "unexpected switch: --bad",
	}, copilot.HookInvocation{})
	if err != nil || failure == nil || !strings.Contains(failure.AdditionalContext, "vcpkg_help") {
		t.Fatalf("failure hook = %+v, %v", failure, err)
	}
}

func TestHandoffToolsCoverEveryMemberAndAreTerminal(t *testing.T) {
	config := newTestRuntimeConfig(t, "registry")
	team := NewTeam(config)
	tripletFile := filepath.Join(config.Workspace, "triplets", config.DefaultTriplet+".cmake")
	mustMkdir(t, filepath.Dir(tripletFile))
	editorPort := filepath.Join(config.Workspace, "ports", "handoff-port")
	mustMkdir(t, editorPort)
	team.editor.setScope(Scope{CWD: config.Workspace, Read: configReadRoots(config), Write: []string{editorPort, config.Scratch}})
	team.triplet.setScope(Scope{CWD: config.Workspace, Read: configReadRoots(config), Write: []string{filepath.Dir(tripletFile)}})

	tests := []struct {
		member  *Member
		tool    string
		payload any
	}{
		{team.planner.Member, "send_detect_request", DetectRequest{Handoff: validHandoff(), Triplets: []string{config.DefaultTriplet}}},
		{team.planner.Member, "send_install_requests", InstallBatch{Handoff: validHandoff(), Requests: []InstallRequest{{Triplet: config.DefaultTriplet, Ports: []string{"x"}}}}},
		{team.planner.Member, "send_baseline_request", BaselineRequest{Handoff: validHandoff(), Ports: []string{"x"}}},
		{team.planner.Member, "send_final_report", FinalReport{Handoff: validHandoff(), Status: "finished"}},
		{team.detector.Member, "send_env_report", EnvReport{Handoff: validHandoff(), Scenario: "registry"}},
		{team.detector.Member, "send_host_facts", HostFacts{Handoff: validHandoff()}},
		{team.installer.Member, "send_install_failure", InstallFailure{Handoff: validHandoff(), Spec: "x", Triplet: config.DefaultTriplet}},
		{team.installer.Member, "send_install_report", InstallReport{Handoff: validHandoff()}},
		{team.doctor.Member, "send_port_goals", PortGoals{Handoff: validHandoff(), Port: "x"}},
		{team.doctor.Member, "send_triplet_goals", TripletGoals{Handoff: validHandoff(), Triplet: config.DefaultTriplet}},
		{team.doctor.Member, "send_blocker", Blocker{Handoff: validHandoff(), Reason: "blocked"}},
		{team.editor.Member, "send_retry_request", RetryRequest{Handoff: validHandoff(), Spec: "x", ChangedFiles: []string{filepath.Join(editorPort, "portfile.cmake")}}},
		{team.triplet.Member, "send_reinstall_request", ReinstallRequest{Handoff: validHandoff(), Triplet: config.DefaultTriplet, TripletFile: tripletFile, Ports: []string{"x"}}},
		{team.triplet.Member, "send_host_facts_request", HostFactsRequest{Handoff: validHandoff(), Question: "host?"}},
		{team.baseline.Member, "send_baseline_report", BaselineReport{Handoff: validHandoff()}},
	}
	for _, test := range tests {
		t.Run(test.tool, func(t *testing.T) {
			team.active.Store(test.member)
			tool := findTool(t, team, test.tool)
			if !tool.IsTerminal {
				t.Fatal("handoff tool is not terminal")
			}
			if _, err := tool.Handler(copilot.ToolInvocation{
				ToolName: tool.Name, Arguments: test.payload, TraceContext: context.Background(),
			}); err != nil {
				t.Fatal(err)
			}
			select {
			case <-test.member.out:
			case <-time.After(time.Second):
				t.Fatal("handoff was not delivered")
			}
		})
	}
}

func TestCustomToolsUseRealExecutablesAndBoundedLogs(t *testing.T) {
	config := newTestRuntimeConfig(t, "registry")
	team := NewTeam(config)

	team.active.Store(team.detector.Member)
	version, err := invokeTool(team, "vcpkg_query", vcpkgQueryParams{Command: "version"})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(version.TextResultForLLM, "version") || !strings.Contains(version.TextResultForLLM, "exit=0") {
		t.Fatalf("vcpkg query = %s", version.TextResultForLLM)
	}
	probe, err := invokeTool(team, "probe_tool", probeToolParams{Tool: "git", Args: []string{"--version"}})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(probe.TextResultForLLM, "git version") {
		t.Fatalf("git probe = %s", probe.TextResultForLLM)
	}
	_, err = invokeTool(team, "probe_tool", probeToolParams{Tool: "python", Args: []string{"-c", "print('unsafe')"}})
	if err == nil {
		t.Fatal("probe_tool accepted an arbitrary interpreter command")
	}

	team.active.Store(team.doctor.Member)
	logPath := filepath.Join(config.Roots.Buildtrees, "tool.log")
	writeFile(t, logPath, strings.Repeat("line\n", 1000)+"needle\n")
	log, err := invokeTool(team, "read_log", readLogParams{Path: logPath, Filter: "needle", Tail: 20})
	if err != nil {
		t.Fatal(err)
	}
	if strings.TrimSpace(log.TextResultForLLM) != "needle" {
		t.Fatalf("filtered log = %q", log.TextResultForLLM)
	}
}

func TestDownloadSHA512UsesHTTPSAndRealHTTPTransport(t *testing.T) {
	content := []byte("real HTTPS response")
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(content)
	}))
	t.Cleanup(server.Close)
	config := newTestRuntimeConfig(t, "registry")
	team := NewTeam(config)
	team.httpClient = server.Client()
	team.active.Store(team.editor.Member)
	result, err := invokeTool(team, "download_sha512", downloadSHA512Params{URL: server.URL})
	if err != nil {
		t.Fatal(err)
	}
	sum := sha512.Sum512(content)
	if result.TextResultForLLM != hex.EncodeToString(sum[:]) {
		t.Fatalf("sha512 = %s", result.TextResultForLLM)
	}
	_, err = invokeTool(team, "download_sha512", downloadSHA512Params{URL: "http://example.invalid/archive"})
	if err == nil {
		t.Fatal("HTTP URL was accepted")
	}
	insecureTarget := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("insecure"))
	}))
	t.Cleanup(insecureTarget.Close)
	redirector := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, insecureTarget.URL, http.StatusFound)
	}))
	t.Cleanup(redirector.Close)
	team.httpClient = redirector.Client()
	_, err = invokeTool(team, "download_sha512", downloadSHA512Params{URL: redirector.URL})
	if err == nil || !strings.Contains(err.Error(), "left HTTPS") {
		t.Fatalf("HTTPS downgrade redirect was accepted: %v", err)
	}
}

func TestGHReadAllowlistRejectsWrites(t *testing.T) {
	allowed := [][]string{
		{"search", "issues", "port failure"},
		{"api", "repos/microsoft/vcpkg/commits"},
		{"api", "--method", "GET", "repos/microsoft/vcpkg/issues"},
		{"pr", "diff", "1"},
	}
	denied := [][]string{
		{"issue", "create"}, {"pr", "create"}, {"api", "--method", "POST", "repos/x/y/issues"},
		{"api", "--method=POST", "repos/x/y/issues"}, {"api", "-XPOST", "repos/x/y/issues"},
		{"api", "--method", "GET", "--method", "POST", "repos/x/y/issues"},
		{"api", "graphql", "-f", "query=mutation { x }"},
		{"api", "-X", "DELETE", "repos/x/y"}, {"api", "--field", "body=x", "repos/x/y"},
	}
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

func TestVersionCommandsStripOverlayEnvironment(t *testing.T) {
	result := withoutEnvironmentNames([]string{
		"VCPKG_ROOT=D:\\vcpkg", "VCPKG_OVERLAY_PORTS=C:\\ports", "VCPKG_OVERLAY_TRIPLETS=C:\\triplets",
	}, "VCPKG_OVERLAY_PORTS", "VCPKG_OVERLAY_TRIPLETS")
	if slices.Equal(result, []string{"VCPKG_OVERLAY_PORTS=C:\\ports"}) ||
		slices.ContainsFunc(result, func(pair string) bool { return strings.HasPrefix(pair, "VCPKG_OVERLAY_") }) {
		t.Fatalf("overlay environment survived: %v", result)
	}
	if !slices.Equal(result, []string{"VCPKG_ROOT=D:\\vcpkg"}) {
		t.Fatalf("environment = %v", result)
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

func TestLiveSDKSingleSessionSimpleDryRun(t *testing.T) {
	if os.Getenv("VCPKG_AGENTS_LIVE_SDK") != "1" {
		t.Skip("set VCPKG_AGENTS_LIVE_SDK=1 for the live Copilot SDK scenario")
	}
	root := createRegistryFixture(t, "agent-live-dry-run", successfulPortfile())
	installRoot := filepath.Join(root, "installed")
	options := Options{
		Prompt: "Dry run agent-live-dry-run for x64-windows.", Model: defaultModel,
		OverlayPorts: []string{filepath.Join(root, "ports")}, BuildtreesRoot: filepath.Join(root, "buildtrees"),
		PackagesRoot: filepath.Join(root, "packages"), InstallRoot: installRoot,
		MaxPortCycles: 2, MaxTripletEdits: 1, LockWait: 5 * time.Minute,
	}
	withWorkingDirectory(t, root, func() {
		config, err := LoadRuntimeConfig(options)
		if err != nil {
			t.Fatal(err)
		}
		defer config.Cleanup()
		team := NewTeam(config)
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
		defer cancel()
		if err := team.CreateSession(ctx); err != nil {
			t.Fatal(err)
		}
		defer team.Close()
		report, err := team.Run(ctx, options.Prompt)
		if err != nil {
			t.Fatal(err)
		}
		if report.Status != "finished" || report.Scenario != "registry" {
			t.Fatalf("report = %+v", report)
		}
		if len(report.Ledger) != 1 || report.Ledger[0].Status != "verified" {
			t.Fatalf("ledger = %+v", report.Ledger)
		}
		list, listErr := team.listStage(context.Background(), InstallRequest{
			Triplet: "x64-windows", Ports: []string{"agent-live-dry-run"},
		})
		if listErr != nil || list.Err != nil {
			t.Fatalf("list after live dry run: %v / %v", listErr, list.Err)
		}
		if anyPortInstalled(list.Summary, []string{"agent-live-dry-run"}) {
			t.Fatalf("live dry run installed the port:\n%s", list.Summary)
		}
	})
}

func newTestRuntimeConfig(t *testing.T, scenario string) *RuntimeConfig {
	t.Helper()
	workspace := t.TempDir()
	scratch := filepath.Join(workspace, ".scratch")
	logs := filepath.Join(scratch, "logs")
	for _, path := range []string{
		filepath.Join(workspace, "ports"), filepath.Join(workspace, "triplets"), filepath.Join(workspace, "versions"),
		logs, filepath.Join(scratch, "buildtrees"), filepath.Join(scratch, "downloads"),
		filepath.Join(scratch, "installed"), filepath.Join(scratch, "packages"),
	} {
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
	roots := VcpkgRoots{
		Vcpkg:      currentVcpkgRoot(t, tools["vcpkg"]),
		Buildtrees: filepath.Join(scratch, "buildtrees"),
		Downloads:  filepath.Join(scratch, "downloads"),
		Installed:  filepath.Join(scratch, "installed"),
		Packages:   filepath.Join(scratch, "packages"),
	}
	triplet := "x64-linux"
	if runtime.GOOS == "windows" {
		triplet = "x64-windows"
	} else if runtime.GOOS == "darwin" {
		triplet = "x64-osx"
	}
	writeScopes := defaultWriteScopes(scenario)
	return &RuntimeConfig{
		Options:          Options{Model: defaultModel, MaxPortCycles: 3, MaxTripletEdits: 1, LockWait: 2 * time.Minute},
		WorkingDirectory: workspace, Workspace: workspace, Scenario: scenario,
		ScenarioEvidence: []string{filepath.Join(workspace, "ports")},
		Tools:            tools, Roots: roots, OverlayPorts: []string{filepath.Join(workspace, "ports")},
		OverlayTriplets: []string{filepath.Join(workspace, "triplets")},
		DefaultTriplet:  triplet, HostTriplet: triplet, VcpkgEnv: scrubbedVcpkgEnvironment(os.Environ(), nil),
		Scratch: scratch, LogDirectory: logs, WriteScopes: writeScopes,
		SecretValues: collectSecretValues(), RunID: "test",
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
	writeFile(t, filepath.Join(root, "versions", "baseline.json"), `{"default":{}}`+"\n")
	createPortFixtureAt(t, filepath.Join(root, "ports"), portName, portfile)
	return root
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

func successfulPortfile() string {
	return `file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/share/${PORT}")
file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/copyright" "MIT")
`
}

func validHandoff() Handoff {
	return Handoff{Goal: "test handoff", Evidence: []string{"unit test"}}
}

func invokeTool(team *Team, name string, arguments any) (copilot.ToolResult, error) {
	tool := findToolNoTest(team, name)
	if tool == nil {
		return copilot.ToolResult{}, fmt.Errorf("tool %s not found", name)
	}
	return tool.Handler(copilot.ToolInvocation{
		ToolName: name, ToolCallID: "test-call", Arguments: arguments, TraceContext: context.Background(),
	})
}

func findToolNoTest(team *Team, name string) *copilot.Tool {
	for index := range team.tools {
		if team.tools[index].Name == name {
			return &team.tools[index]
		}
	}
	return nil
}

func findTool(t *testing.T, team *Team, name string) *copilot.Tool {
	t.Helper()
	tool := findToolNoTest(team, name)
	if tool == nil {
		t.Fatalf("tool %s not found", name)
	}
	return tool
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

var _ io.Reader = (*strings.Reader)(nil)
