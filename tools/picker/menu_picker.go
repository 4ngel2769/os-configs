package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type menuItem struct {
	ID       string `json:"id"`
	Label    string `json:"label"`
	Subtitle string `json:"subtitle,omitempty"`
}

type menuInput struct {
	Banner      bannerInfo `json:"banner"`
	Mode        string     `json:"mode"`
	Title       string     `json:"title"`
	Subtitle    string     `json:"subtitle,omitempty"`
	Body        string     `json:"body,omitempty"`
	Message     string     `json:"message,omitempty"`
	DefaultYes  bool       `json:"default_yes"`
	YesLabel    string     `json:"yes_label,omitempty"`
	NoLabel     string     `json:"no_label,omitempty"`
	ShowBanner  bool       `json:"show_banner"`
	Items       []menuItem `json:"items,omitempty"`
}

type menuOutput struct {
	Choice    string `json:"choice,omitempty"`
	Confirmed *bool  `json:"confirmed,omitempty"`
}

type menuModel struct {
	in         menuInput
	cursor     int
	confirmYes bool
	width      int
	height     int
	quitting   bool
	done       bool
}

func (m menuModel) Init() tea.Cmd { return nil }

func (m menuModel) filteredItems() []menuItem {
	return m.in.Items
}

func (m *menuModel) moveCursor(delta int) {
	items := m.filteredItems()
	if len(items) == 0 {
		return
	}
	m.cursor += delta
	if m.cursor < 0 {
		m.cursor = len(items) - 1
	}
	if m.cursor >= len(items) {
		m.cursor = 0
	}
}

func (m menuModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil
	case tea.KeyMsg:
		switch m.in.Mode {
		case "confirm":
			switch msg.String() {
			case "ctrl+c", "q", "esc":
				m.quitting = true
				return m, tea.Quit
			case "left", "h", "y":
				m.confirmYes = true
			case "right", "l", "n":
				m.confirmYes = false
			case "tab":
				m.confirmYes = !m.confirmYes
			case "enter":
				m.done = true
				return m, tea.Quit
			}
		case "info":
			switch msg.String() {
			case "ctrl+c", "q", "esc":
				m.quitting = true
				return m, tea.Quit
			case "enter":
				m.done = true
				return m, tea.Quit
			}
		default:
			switch msg.String() {
			case "ctrl+c", "q", "esc":
				m.quitting = true
				return m, tea.Quit
			case "up", "k":
				m.moveCursor(-1)
			case "down", "j":
				m.moveCursor(1)
			case "enter":
				if len(m.filteredItems()) > 0 {
					m.done = true
					return m, tea.Quit
				}
			}
		}
	}
	return m, nil
}

func (m menuModel) renderList() string {
	th := appTUI.Theme
	header := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(m.width).Foreground(th.accent()).Render(m.in.Title)
	sub := ""
	if m.in.Subtitle != "" {
		sub = lipgloss.NewStyle().Align(lipgloss.Center).Width(m.width).Foreground(th.muted()).Render(m.in.Subtitle)
	}

	listW := min(m.width-8, 72)
	var rows []string
	items := m.filteredItems()
	for i, item := range items {
		label := item.Label
		if item.Subtitle != "" {
			label = fmt.Sprintf("%s — %s", item.Label, item.Subtitle)
		}
		label = truncateRunes(label, listW-4)
		var line string
		if i == m.cursor {
			line = "▸ " + lipgloss.NewStyle().Bold(true).Foreground(th.selected()).Render(label)
		} else {
			line = "  " + lipgloss.NewStyle().Foreground(th.muted()).Render(label)
		}
		rows = append(rows, lipgloss.NewStyle().Width(listW).Render(line))
	}

	list := lipgloss.JoinVertical(lipgloss.Left, rows...)
	block := lipgloss.JoinVertical(lipgloss.Center, header, sub, "", list)
	return lipgloss.NewStyle().Width(m.width).Align(lipgloss.Center).Render(block)
}

func (m menuModel) confirmLabels() (yes, no string) {
	yes = strings.TrimSpace(m.in.YesLabel)
	no = strings.TrimSpace(m.in.NoLabel)
	if yes == "" {
		yes = tuiString("confirm_yes", "Yes")
	}
	if no == "" {
		no = tuiString("confirm_no", "No")
	}
	return yes, no
}

func (m menuModel) renderConfirm() string {
	title := strings.TrimSpace(m.in.Title)
	if title == "" {
		title = "Confirm"
	}

	yesLabel, noLabel := m.confirmLabels()
	buttons := renderButtonPair(yesLabel, noLabel, m.confirmYes, 3)
	maxW := min(m.width-8, 64)
	dialog := renderDialog(title, strings.TrimSpace(m.in.Body), strings.TrimSpace(m.in.Message), buttons, maxW)
	return centerBlock(m.width, dialog)
}

func (m menuModel) renderInfo() string {
	th := appTUI.Theme
	header := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(m.width).Foreground(th.accent()).Render(m.in.Title)

	body := ""
	if m.in.Body != "" {
		body = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(th.accent()).
			Padding(1, 2).
			MaxWidth(min(m.width-10, 76)).
			Align(lipgloss.Left).
			Foreground(th.body()).
			Render(m.in.Body)
	}

	continueLabel := tuiString("info_continue", "Continue")
	btn := renderBorderedButton(continueLabel, true, buttonPrimary)
	btn = lipgloss.NewStyle().Margin(1, 0).Render(btn)

	parts := []string{header}
	if body != "" {
		parts = append(parts, "", centerBlock(m.width, body))
	}
	parts = append(parts, centerBlock(m.width, btn))
	return lipgloss.JoinVertical(lipgloss.Center, parts...)
}

func (m menuModel) View() string {
	w := m.width
	if w < 40 {
		w = 40
	}
	h := m.height
	if h < 16 {
		h = 16
	}

	var body string
	var hint string

	switch m.in.Mode {
	case "confirm":
		body = m.renderConfirm()
		hint = lipgloss.NewStyle().Align(lipgloss.Center).Width(w).Foreground(appTUI.Theme.muted()).
			Render(tuiString("confirm_hint", "←/→ toggle · Enter submit"))
		if !m.in.ShowBanner {
			content := lipgloss.JoinVertical(lipgloss.Center, body, "", hint)
			return lipgloss.Place(w, h, lipgloss.Center, lipgloss.Center, content)
		}
	case "info":
		body = m.renderInfo()
		hint = lipgloss.NewStyle().Align(lipgloss.Center).Width(w).Foreground(appTUI.Theme.muted()).
			Render(tuiString("info_hint", "Enter continue"))
	default:
		body = m.renderList()
		hint = lipgloss.NewStyle().Align(lipgloss.Center).Width(w).Foreground(appTUI.Theme.muted()).
			Render(tuiString("list_hint", "↑↓ move · Enter select"))
	}

	banner := renderBanner(w, m.in.Banner)
	content := lipgloss.JoinVertical(lipgloss.Center, banner, "", body, "", hint)
	return lipgloss.Place(w, h, lipgloss.Center, lipgloss.Top, content)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func runMenuPicker(inputPath, outputPath string) error {
	raw, err := os.ReadFile(inputPath)
	if err != nil {
		return err
	}
	var in menuInput
	if err := json.Unmarshal(raw, &in); err != nil {
		return err
	}

	m := menuModel{
		in:         in,
		confirmYes: in.DefaultYes,
	}
	if in.Mode != "confirm" && len(in.Items) > 0 {
		m.cursor = 0
	}

	p := tea.NewProgram(m, tea.WithAltScreen())
	final, err := p.Run()
	if err != nil {
		return err
	}

	fm := final.(menuModel)
	if fm.quitting && !fm.done {
		os.Exit(1)
	}

	out := menuOutput{}
	switch in.Mode {
	case "confirm":
		v := fm.confirmYes
		out.Confirmed = &v
	case "info":
		// no payload
	default:
		items := fm.filteredItems()
		if fm.cursor >= 0 && fm.cursor < len(items) {
			out.Choice = items[fm.cursor].ID
		}
	}

	dest, err := openOutput(outputPath)
	if err != nil {
		return err
	}
	defer dest.Close()
	enc := json.NewEncoder(dest)
	enc.SetIndent("", "  ")
	return enc.Encode(out)
}
