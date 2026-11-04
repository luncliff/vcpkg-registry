package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"time"

	copilot "github.com/github/copilot-sdk/go"
	"github.com/github/copilot-sdk/go/rpc"
)

const portSearchSystemMessage = `
Detect the vcpkg location and the current git root.
Search which ports are available to meet the requirement of the user prompt.
Report them in extremely brief messages.
`

const toolCheckSystemMessage = `
Ensure the registered tools are executable.
Run each tool's version or help command in sequence with execute_tool.
Report the response information in extremely brief messages.
`

// judgeSystemMessage takes the user prompt through %s.
const judgeSystemMessage = `
Decide whether the goals in the user prompt are achieved.
Each message is the output of the agent team for one iteration.
Answer ACHIEVED or ITERATE on the first line, then give the reason in one sentence.

User prompt:
%s
`

// Skill directories. Repository-level directories join the git root; user-level directories join the home directory.
// https://github.com/github/copilot-sdk/blob/v1.0.28/docs/features/skills.md
const (
	githubSkills  = ".github/skills"
	claudeSkills  = ".claude/skills"
	codexSkills   = ".codex/skills"
	agentsSkills  = ".agents/skills"
	copilotSkills = ".copilot/skills"
)

var (
	repositorySkills = []string{githubSkills, claudeSkills, codexSkills, agentsSkills}
	userSkills       = []string{copilotSkills, claudeSkills, codexSkills, agentsSkills}
)

var (
	prompt  = flag.String("prompt", "", "prompt sent in every iteration (required)")
	verbose = flag.Bool("verbose", false, "log at DEBUG level; the default level is INFO")
)

var (
	toolPaths          map[string]string
	vcpkgEnvironment   map[string]string
	vcpkgManifest      string
	vcpkgConfiguration string
	gitRoot            string
	skillDirectories   []string
)

func SetupLogging(output io.Writer, verbose bool){
	level := slog.LevelInfo
	if verbose {
		level = slog.LevelDebug
	}
	slog.SetDefault(slog.New(slog.NewTextHandler(output, &slog.HandlerOptions{Level: level})))
	slog.SetFlags(log.Ldate | log.Ltime | log.Lmicroseconds)
}

// init parses the flags and sets the log level, then stores the environment checks in the globals and logs them.
func init() {
	flag.Parse()
	SetupLogging(os.Stdout, *verbose)

	toolPaths = CheckSystemToolPaths()
	for name, path := range toolPaths {
		slog.Info("tool", "name", name, "path", path)
	}

	vcpkgEnvironment = CheckVcpkgEnvironmentVariables()
	for name, value := range vcpkgEnvironment {
		slog.Info("environment", "name", name, "value", value)
	}

	vcpkgManifest = CheckVcpkgManifest()
	slog.Info("vcpkg manifest", "path", vcpkgManifest)

	vcpkgConfiguration = CheckVcpkgConfiguration(vcpkgManifest, vcpkgEnvironment["VCPKG_ROOT"])
	slog.Info("vcpkg configuration", "path", vcpkgConfiguration)

	gitRoot = CheckGitRoot()
	slog.Info("git root", "path", gitRoot)

	skillDirectories = CheckSkillDirectories(gitRoot)
	for _, directory := range skillDirectories {
		slog.Info("skill directory", "path", directory)
	}
}

// CheckGitRoot returns the top-level directory of the git repository at the working directory. Empty means none.
func CheckGitRoot() string {
	out, err := exec.Command(toolPaths["git"], "rev-parse", "--show-toplevel").Output()
	if err != nil {
		return ""
	}
	return filepath.Clean(strings.TrimSpace(string(out)))
}

// CheckSkillDirectories returns the existing repository-level and user-level skill directories.
func CheckSkillDirectories(gitRoot string) []string {
	var candidates []string
	if gitRoot != "" {
		for _, directory := range repositorySkills {
			candidates = append(candidates, filepath.Join(gitRoot, directory))
		}
	}
	if home, err := os.UserHomeDir(); err == nil {
		for _, directory := range userSkills {
			candidates = append(candidates, filepath.Join(home, directory))
		}
	}
	var directories []string
	for _, directory := range candidates {
		if info, err := os.Stat(directory); err == nil && info.IsDir() {
			directories = append(directories, directory)
		}
	}
	return directories
}

// CheckSystemToolPaths returns the path of each tool found on PATH.
func CheckSystemToolPaths() map[string]string {
	paths := make(map[string]string)
	for _, name := range []string{"go", "copilot", "curl", "tar", "zip", "unzip", "git", "gh", "cmake", "ninja", "vcpkg"} {
		if path, err := exec.LookPath(name); err == nil {
			paths[name] = path
		}
	}
	return paths
}

// CheckVcpkgEnvironmentVariables returns each VCPKG_* environment variable that is set.
// https://learn.microsoft.com/en-us/vcpkg/users/config-environment
func CheckVcpkgEnvironmentVariables() map[string]string {
	names := []string{
		"VCPKG_ROOT", "VCPKG_DOWNLOADS",
		"VCPKG_DEFAULT_TRIPLET", "VCPKG_DEFAULT_HOST_TRIPLET",
		"VCPKG_OVERLAY_PORTS", "VCPKG_OVERLAY_TRIPLETS",
		"VCPKG_BINARY_SOURCES", "VCPKG_DEFAULT_BINARY_CACHE", "VCPKG_BINARY_CACHE_COMPRESSION_LEVEL",
		"VCPKG_NUGET_REPOSITORY", "VCPKG_USE_NUGET_CACHE",
		"VCPKG_FEATURE_FLAGS", "VCPKG_KEEP_ENV_VARS", "VCPKG_MAX_CONCURRENCY",
		"VCPKG_FORCE_DOWNLOADED_BINARIES", "VCPKG_FORCE_SYSTEM_BINARIES",
		"VCPKG_DISABLE_METRICS", "VCPKG_NO_CI",
	}
	if runtime.GOOS == "windows" {
		names = append(names, "VCPKG_VISUAL_STUDIO_PATH")
	}

	values := make(map[string]string)
	for _, name := range names {
		if value, ok := os.LookupEnv(name); ok {
			values[name] = value
		}
	}
	return values
}

// CheckVcpkgManifest returns the path of the vcpkg.json that vcpkg finds from the working directory.
// vcpkg searches the working directory, then its parents. An empty path means classic mode.
// https://learn.microsoft.com/en-us/vcpkg/concepts/manifest-mode
// https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json
func CheckVcpkgManifest() string {
	dir, err := os.Getwd()
	if err != nil {
		return ""
	}
	for {
		path := filepath.Join(dir, "vcpkg.json")
		if _, err := os.Stat(path); err == nil {
			return path
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return ""
		}
		dir = parent
	}
}

// CheckVcpkgConfiguration returns the path of the configuration that vcpkg uses. An empty path means none.
//   - Manifest mode: vcpkg-configuration.json beside the manifest, or the manifest itself
//     when its "configuration" (older spelling "vcpkg-configuration") field embeds it.
//   - Classic mode (empty manifest): vcpkg-configuration.json in the vcpkg root.
//
// https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json
func CheckVcpkgConfiguration(manifest, vcpkgRoot string) string {
	dir := vcpkgRoot
	if manifest != "" {
		dir = filepath.Dir(manifest)
	}
	if dir != "" {
		path := filepath.Join(dir, "vcpkg-configuration.json")
		if _, err := os.Stat(path); err == nil {
			return path
		}
	}
	if manifest == "" {
		return ""
	}

	content, err := os.ReadFile(manifest)
	if err != nil {
		return ""
	}
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(content, &fields); err != nil {
		return ""
	}
	if _, ok := fields["configuration"]; ok {
		return manifest
	}
	if _, ok := fields["vcpkg-configuration"]; ok {
		return manifest
	}
	return ""
}

// main starts the client and the agent goroutines, then iterates until the judge
// decides the goals in the prompt are achieved.
func main() {
	if *prompt == "" {
		slog.Error("--prompt is required")
		flag.Usage()
		os.Exit(2)
	}

	ctx := context.Background()
	client := copilot.NewClient(nil)
	if err := client.Start(ctx); err != nil {
		slog.Error("start client", "error", err)
		os.Exit(1)
	}
	defer client.Stop()
	slog.Info("vcpkg-agents started")

	input := make(chan copilot.AssistantMessageData)
	messages := make(chan copilot.AssistantMessageData)
	output := make(chan copilot.AssistantMessageData)
	portSearchAgent := NewPortSearchAgent(client)
	go portSearchAgent.Run(ctx, input, messages)
	toolCheckAgent := NewToolCheckAgent(client)
	go toolCheckAgent.Run(ctx, messages, output)
	slog.Debug("agent goroutines ready; sessions start when messages arrive")

	judge, err := NewJudge(ctx, client, *prompt)
	if err != nil {
		slog.Error("create session", "agent", "judge", "error", err)
		os.Exit(1)
	}
	defer judge.Close(ctx)

	// Ralph loop: every iteration sends the same prompt until the judge decides the goals are achieved.
	// https://ghuntley.com/ralph/
	for {
		input <- copilot.AssistantMessageData{Content: *prompt}
		report, ok := <-output
		if !ok {
			slog.Warn("agents stopped")
			break
		}
		if achieved, err := judge.Achieved(ctx, report); err != nil || achieved {
			if err != nil {
				slog.Error("decide", "agent", "judge", "error", err)
			}
			break
		}
	}
	close(input)

	// Wait for the agents to report usage, disconnect their sessions, and close output.
	for range output {
	}
}

// Judge owns one session for the whole loop, so it keeps the context of every iteration.
type Judge struct {
	session *copilot.Session
}

// NewJudge creates the judge session for the goals in prompt. The session has only the skill tool.
func NewJudge(ctx context.Context, client *copilot.Client, prompt string) (*Judge, error) {
	j := &Judge{}
	session, err := client.CreateSession(ctx, &copilot.SessionConfig{
		Model:               "gpt-6-luna",
		SkillDirectories:    skillDirectories,
		SystemMessage:       &copilot.SystemMessageConfig{Content: fmt.Sprintf(judgeSystemMessage, prompt)},
		AvailableTools:      []string{"skill"},
		OnPermissionRequest: j.permissionRequest,
	})
	if err != nil {
		return nil, err
	}
	j.session = session
	slog.Debug("session created", "agent", "judge", "session", session.SessionID)
	return j, nil
}

// permissionRequest rejects every permission request.
func (j *Judge) permissionRequest(request copilot.PermissionRequest, _ copilot.PermissionInvocation) (rpc.PermissionDecision, error) {
	slog.Warn("permission rejected", "agent", "judge", "kind", request.Kind())
	return &rpc.PermissionDecisionReject{}, nil
}

// Achieved sends the team report of one iteration and reports whether the goals are achieved.
func (j *Judge) Achieved(ctx context.Context, report copilot.AssistantMessageData) (bool, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Minute)
	defer cancel()
	response, err := j.session.SendAndWait(ctx, copilot.MessageOptions{Prompt: report.Content})
	if err != nil {
		return false, fmt.Errorf("send: %w", err)
	}
	decision, ok := response.Data.(*copilot.AssistantMessageData)
	if !ok || decision == nil {
		return false, fmt.Errorf("expected assistant message, received %T", response.Data)
	}
	slog.Info("reply", "agent", "judge", "content", decision.Content)
	return strings.HasPrefix(strings.TrimSpace(decision.Content), "ACHIEVED"), nil
}

// Close reports the judge usage and disconnects its session.
func (j *Judge) Close(ctx context.Context) {
	logUsage(ctx, "judge", j.session)
	if err := j.session.Disconnect(); err != nil {
		slog.Error("disconnect", "agent", "judge", "error", err)
	}
}

// logUsage reports the accumulated usage of a session. Call it before the session disconnects.
// https://github.com/github/copilot-sdk/blob/v1.0.28/docs/features/usage-and-billing.md
func logUsage(ctx context.Context, name string, session *copilot.Session) {
	metrics, err := session.RPC.Usage.GetMetrics(ctx)
	if err != nil {
		slog.Error("usage", "agent", name, "error", err)
		return
	}
	aiCredits := 0.0
	if metrics.TotalNanoAiu != nil {
		aiCredits = *metrics.TotalNanoAiu / 1e9
	}
	slog.Info("usage", "agent", name, "ai_credits", aiCredits, "premium_requests", metrics.TotalPremiumRequestCost)
	for model, m := range metrics.ModelMetrics {
		slog.Info("usage", "agent", name, "model", model, "requests", m.Requests.Count,
			"input_tokens", m.Usage.InputTokens, "output_tokens", m.Usage.OutputTokens)
	}
}

// PortSearchAgent owns a session with a read-only tool, limited to the git root and VCPKG_ROOT,
// and a vcpkg install tool. The pre-tool-use hook blocks vcpkg install without --dry-run.
type PortSearchAgent struct {
	client  *copilot.Client
	session *copilot.Session
	roots   map[string]string
}

// NewPortSearchAgent returns an agent whose session starts with the first message.
func NewPortSearchAgent(client *copilot.Client) *PortSearchAgent {
	return &PortSearchAgent{client: client}
}

type readPathParams struct {
	Path string `json:"path" jsonschema:"absolute path inside the git root or VCPKG_ROOT; empty returns both roots"`
}

type vcpkgInstallParams struct {
	Args []string `json:"args" jsonschema:"arguments after install, such as --dry-run yyjson"`
}

// Run answers each input message and forwards the reply to output.
// The session starts with the first message.
func (a *PortSearchAgent) Run(ctx context.Context, input <-chan copilot.AssistantMessageData, output chan<- copilot.AssistantMessageData) {
	defer close(output)
	defer a.close(ctx)
	for message := range input {
		if a.session == nil {
			if err := a.start(ctx); err != nil {
				slog.Error("create session", "agent", "port search", "error", err)
				return
			}
		}
		reply, err := a.ask(ctx, message)
		if err != nil {
			slog.Error("ask", "agent", "port search", "error", err)
			return
		}
		slog.Info("reply", "agent", "port search", "content", reply.Content)
		output <- *reply
	}
}

// start creates the session with the read_path and vcpkg_install tools.
func (a *PortSearchAgent) start(ctx context.Context) error {
	a.roots = map[string]string{"VCPKG_ROOT": vcpkgEnvironment["VCPKG_ROOT"], "git root": gitRoot}

	readPath := copilot.DefineTool("read_path", "Read a file or list a directory inside the git root or VCPKG_ROOT.", a.readPath)
	readPath.SkipPermission = true
	vcpkgInstall := copilot.DefineTool("vcpkg_install", "Run `vcpkg install` with arguments to verify the target ports and their dependencies. The arguments must contain --dry-run.", a.vcpkgInstall)

	session, err := a.client.CreateSession(ctx, &copilot.SessionConfig{
		Model:               "gpt-6-luna",
		SkillDirectories:    skillDirectories,
		SystemMessage:       &copilot.SystemMessageConfig{Content: portSearchSystemMessage},
		Tools:               []copilot.Tool{readPath, vcpkgInstall},
		AvailableTools:      []string{"read_path", "vcpkg_install", "skill"},
		Hooks:               &copilot.SessionHooks{OnPreToolUse: a.preToolUse},
		OnPermissionRequest: a.permissionRequest,
	})
	if err != nil {
		return err
	}
	a.session = session
	slog.Debug("session created", "agent", "port search", "session", session.SessionID)
	return nil
}

// readPath returns the roots for an empty path, the content of a file, or the entries of a directory.
// The path must be inside the git root or VCPKG_ROOT.
func (a *PortSearchAgent) readPath(params readPathParams, _ copilot.ToolInvocation) (any, error) {
	slog.Debug("read_path", "agent", "port search", "path", params.Path)
	if params.Path == "" {
		return a.roots, nil
	}
	path, err := filepath.Abs(params.Path)
	if err != nil {
		return nil, err
	}
	if !insideAny(path, a.roots) {
		return nil, fmt.Errorf("%s is outside the git root and VCPKG_ROOT", path)
	}
	info, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if !info.IsDir() {
		content, err := os.ReadFile(path)
		return string(content), err
	}
	entries, err := os.ReadDir(path)
	if err != nil {
		return nil, err
	}
	names := make([]string, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() {
			names = append(names, entry.Name()+"/")
		} else {
			names = append(names, entry.Name())
		}
	}
	return names, nil
}

// vcpkgInstall runs `vcpkg install` with the arguments and returns its exit status and output.
func (a *PortSearchAgent) vcpkgInstall(params vcpkgInstallParams, _ copilot.ToolInvocation) (string, error) {
	slog.Debug("vcpkg_install", "agent", "port search", "args", params.Args)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	out, err := exec.CommandContext(ctx, toolPaths["vcpkg"], append([]string{"install"}, params.Args...)...).CombinedOutput()
	return fmt.Sprintf("error: %v\n%s", err, out), nil
}

// preToolUse is the harness: every vcpkg_install invocation must contain --dry-run.
func (a *PortSearchAgent) preToolUse(input copilot.PreToolUseHookInput, _ copilot.HookInvocation) (*copilot.PreToolUseHookOutput, error) {
	if input.ToolName != "vcpkg_install" {
		return nil, nil
	}
	args, _ := input.ToolArgs.(map[string]any)
	list, _ := args["args"].([]any)
	if !slices.Contains(list, any("--dry-run")) {
		slog.Warn("hook denied", "agent", "port search", "tool", input.ToolName, "args", list)
		return &copilot.PreToolUseHookOutput{
			PermissionDecision:       "deny",
			PermissionDecisionReason: "vcpkg install must contain --dry-run",
		}, nil
	}
	slog.Debug("hook allowed", "agent", "port search", "tool", input.ToolName, "args", list)
	return &copilot.PreToolUseHookOutput{PermissionDecision: "allow"}, nil
}

// permissionRequest approves vcpkg_install and rejects every other request.
func (a *PortSearchAgent) permissionRequest(request copilot.PermissionRequest, _ copilot.PermissionInvocation) (rpc.PermissionDecision, error) {
	if custom, ok := request.(*rpc.PermissionRequestCustomTool); ok && custom.ToolName == "vcpkg_install" {
		return &rpc.PermissionDecisionApproveOnce{}, nil
	}
	slog.Warn("permission rejected", "agent", "port search", "kind", request.Kind())
	return &rpc.PermissionDecisionReject{}, nil
}

// ask sends one message and waits for the assistant reply.
func (a *PortSearchAgent) ask(ctx context.Context, message copilot.AssistantMessageData) (*copilot.AssistantMessageData, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Minute)
	defer cancel()
	response, err := a.session.SendAndWait(ctx, copilot.MessageOptions{Prompt: message.Content})
	if err != nil {
		return nil, err
	}
	reply, ok := response.Data.(*copilot.AssistantMessageData)
	if !ok || reply == nil {
		return nil, fmt.Errorf("expected assistant message, received %T", response.Data)
	}
	return reply, nil
}

// close reports usage and disconnects the session when it was started.
func (a *PortSearchAgent) close(ctx context.Context) {
	if a.session == nil {
		return
	}
	logUsage(ctx, "port search", a.session)
	if err := a.session.Disconnect(); err != nil {
		slog.Error("disconnect", "agent", "port search", "error", err)
	}
}

// insideAny reports whether path is inside one of the roots.
func insideAny(path string, roots map[string]string) bool {
	for _, root := range roots {
		if root == "" {
			continue
		}
		if rel, err := filepath.Rel(root, path); err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
			return true
		}
	}
	return false
}

// ToolCheckAgent owns a session with one execution tool. The pre-tool-use hook blocks unregistered tools.
// https://github.com/github/copilot-sdk/blob/v1.0.28/docs/hooks/pre-tool-use.md
type ToolCheckAgent struct {
	client  *copilot.Client
	session *copilot.Session
}

// NewToolCheckAgent returns an agent whose session starts with the first message.
func NewToolCheckAgent(client *copilot.Client) *ToolCheckAgent {
	return &ToolCheckAgent{client: client}
}

type executeToolParams struct {
	Tool string   `json:"tool" jsonschema:"registered tool name"`
	Args []string `json:"args" jsonschema:"arguments, such as --version or --help"`
}

// Run answers each input message and forwards the reply to output.
// The session starts with the first message.
func (a *ToolCheckAgent) Run(ctx context.Context, input <-chan copilot.AssistantMessageData, output chan<- copilot.AssistantMessageData) {
	defer close(output)
	defer a.close(ctx)
	for message := range input {
		if a.session == nil {
			if err := a.start(ctx); err != nil {
				slog.Error("create session", "agent", "tool check", "error", err)
				return
			}
		}
		reply, err := a.ask(ctx, message)
		if err != nil {
			slog.Error("ask", "agent", "tool check", "error", err)
			return
		}
		slog.Info("reply", "agent", "tool check", "content", reply.Content)
		output <- *reply
	}
}

// start creates the session with the execute_tool tool and the hook for registered tools.
func (a *ToolCheckAgent) start(ctx context.Context) error {
	names := make([]string, 0, len(toolPaths))
	for name := range toolPaths {
		names = append(names, name)
	}
	slices.Sort(names)
	executeTool := copilot.DefineTool("execute_tool", "Execute a registered tool with arguments and return its exit status and output. Registered tools: "+strings.Join(names, ", "), a.executeTool)

	session, err := a.client.CreateSession(ctx, &copilot.SessionConfig{
		Model:               "gpt-6-luna",
		SkillDirectories:    skillDirectories,
		SystemMessage:       &copilot.SystemMessageConfig{Content: toolCheckSystemMessage},
		Tools:               []copilot.Tool{executeTool},
		AvailableTools:      []string{"execute_tool", "skill"},
		Hooks:               &copilot.SessionHooks{OnPreToolUse: a.preToolUse},
		OnPermissionRequest: a.permissionRequest,
	})
	if err != nil {
		return err
	}
	a.session = session
	slog.Debug("session created", "agent", "tool check", "session", session.SessionID)
	return nil
}

// executeTool runs a registered tool with the arguments and returns its exit status and output.
func (a *ToolCheckAgent) executeTool(params executeToolParams, _ copilot.ToolInvocation) (string, error) {
	slog.Debug("execute_tool", "agent", "tool check", "tool", params.Tool, "args", params.Args)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, toolPaths[params.Tool], params.Args...).CombinedOutput()
	return fmt.Sprintf("error: %v\n%s", err, out), nil
}

// preToolUse blocks execute_tool when its tool is not in toolPaths.
func (a *ToolCheckAgent) preToolUse(input copilot.PreToolUseHookInput, _ copilot.HookInvocation) (*copilot.PreToolUseHookOutput, error) {
	if input.ToolName != "execute_tool" {
		return nil, nil
	}
	args, _ := input.ToolArgs.(map[string]any)
	name, _ := args["tool"].(string)
	if _, ok := toolPaths[name]; !ok {
		slog.Warn("hook denied", "agent", "tool check", "tool", input.ToolName, "args", input.ToolArgs)
		return &copilot.PreToolUseHookOutput{
			PermissionDecision:       "deny",
			PermissionDecisionReason: fmt.Sprintf("%q is not a registered tool", name),
		}, nil
	}
	slog.Debug("hook allowed", "agent", "tool check", "tool", input.ToolName, "args", input.ToolArgs)
	return &copilot.PreToolUseHookOutput{PermissionDecision: "allow"}, nil
}

// permissionRequest approves execute_tool and rejects every other request.
func (a *ToolCheckAgent) permissionRequest(request copilot.PermissionRequest, _ copilot.PermissionInvocation) (rpc.PermissionDecision, error) {
	if custom, ok := request.(*rpc.PermissionRequestCustomTool); ok && custom.ToolName == "execute_tool" {
		return &rpc.PermissionDecisionApproveOnce{}, nil
	}
	slog.Warn("permission rejected", "agent", "tool check", "kind", request.Kind())
	return &rpc.PermissionDecisionReject{}, nil
}

// ask sends one message and waits for the assistant reply.
func (a *ToolCheckAgent) ask(ctx context.Context, message copilot.AssistantMessageData) (*copilot.AssistantMessageData, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Minute)
	defer cancel()
	response, err := a.session.SendAndWait(ctx, copilot.MessageOptions{Prompt: message.Content})
	if err != nil {
		return nil, err
	}
	reply, ok := response.Data.(*copilot.AssistantMessageData)
	if !ok || reply == nil {
		return nil, fmt.Errorf("expected assistant message, received %T", response.Data)
	}
	return reply, nil
}

// close reports usage and disconnects the session when it was started.
func (a *ToolCheckAgent) close(ctx context.Context) {
	if a.session == nil {
		return
	}
	logUsage(ctx, "tool check", a.session)
	if err := a.session.Disconnect(); err != nil {
		slog.Error("disconnect", "agent", "tool check", "error", err)
	}
}
