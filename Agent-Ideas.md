Hey team! I've created two custom Copilot agents that can help streamline our development workflow. Here's a quick overview and how to get started.
Agent 1: Jira BDD & Implementation Analysis Agent
What it does:
Give it a Jira ticket ID (e.g., ACP-53) and it automatically:
Fetches full ticket details from Jira (description, AC, comments, subtasks, linked issues)
Detects and fetches linked Spike tickets for R&D context
Runs an Acceptance Criteria gap analysis and generates supplementary AC if needed
Extracts embedded test cases from the ticket
For Bug tickets: performs root cause analysis by scanning the codebase
Generates 15+ BDD scenarios in Gherkin format with edge cases across 15 categories
Scans the entire codebase for reusable components, hooks, types, utils, and services
Produces a phased implementation plan with file impact analysis
Outputs everything into a single consolidated Markdown file at docs/bdd/{TICKET_ID}.md
Advantages:
Eliminates manual context-gathering — no more switching between Jira, codebase, and docs
Ensures comprehensive test coverage with systematic edge case generation
Identifies reusable code you might not know exists in the codebase
Catches AC gaps before development starts, reducing rework
For bugs, traces root cause directly in the codebase with confidence levels
Spike research findings are automatically incorporated into the implementation plan
Creates a single source of truth document for each ticket
Setup — Jira Configuration:
Create a .env file in your workspace root with:

JavaScript
JavaScript
JIRA_BASE_URL=https://your-org.atlassian.net
JIRA_API_TOKEN=your-api-token
JIRA_USER_EMAIL=your-email@company.com
 
To generate your Jira API token: Go to https://id.atlassian.com/manage-profile/security/api-tokens → Create API token
Place the agent file at ImplementationAnalysis.agent.md in your repo
In Copilot Chat, select the agent and just type a ticket ID like ACP-1595
Agent 2: Code Review Agent
What it does:
Performs comprehensive code reviews against:
AiBLE coding standards (indentation, naming, error handling, testing, Git practices)
Language-specific best practices (React, TypeScript, Node.js, Python, etc.)
Code quality principles (DRY, SOLID, Single Responsibility)
Can review specific files, branches, commits, or uncommitted changes
Supports branch comparisons (e.g., "Review feature/ABC-123 against main")
Advantages:
Consistent reviews against our team's actual coding standards every time
Catches issues before PR review — saves reviewer time
Each finding includes the specific guideline reference, severity level, and actionable fix with code examples
Helps onboard new team members by teaching standards through feedback
Covers security concerns, performance issues, testing gaps, and documentation in one pass
Setup:
Place the agent file at review.agent.md in your repo
No additional configuration needed — it works directly with your local codebase
Usage examples:
"Review src/components/MyComponent.tsx"
"Review feature/ACP-123 against main"
"Review my uncommitted changes"
"Review this branch"
General Setup (Both Agents):
Requires VS Code with GitHub Copilot Chat extension
Agent files go in agents directory in your repo
They appear as selectable agents in the Copilot Chat panel
Give them a try and share your feedback! Happy to walk through a live demo if anyone's interested.
