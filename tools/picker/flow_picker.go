package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type flowItem struct {
	ID       string `json:"id"`
	Label    string `json:"label"`
	Subtitle string `json:"subtitle,omitempty"`
}

type flowInput struct {
	Banner        *bannerInfo `json:"banner,omitempty"`
	Step          int         `json:"step,omitempty"`
	Total         int         `json:"total,omitempty"`
	Title         string      `json:"title"`
	Subtitle      string      `json:"subtitle,omitempty"`
	Message       string      `json:"message,omitempty"`
	Body          string      `json:"body,omitempty"`
	Items         []flowItem  `json:"items,omitempty"`
	Multi         bool        `json:"multi,omitempty"`
	DefaultID     string      `json:"default_id,omitempty"`
	ShowBack      bool        `json:"show_back,omitempty"`
	BackLabel     string      `json:"back_label,omitempty"`
	ContinueLabel string      `json:"continue_label,omitempty"`
}

type flowOutput struct {
	Choice string `json:"choice,omitempty"`
	Back   bool   `json:"back"`
}

type flowModel struct {
	in       flowInput
	cursor   int
	checked  map[string]bool
	focus    int // 0 items, 1 footer
	footer   int // 0 back, 1 continue
	width    int
	height   int
	quitting bool
	done     bool
	back     bool
}

func (m flowModel) Init() tea.Cmd { return nil }

func (m *flowModel) moveCursor(delta int) {
	if len(m.in.Items) == 0 {
		return
	}
	m.cursor += delta
	if m.cursor < 0 {
		m.cursor = len(m.in.Items) - 1
	}
	if m.cursor >= len(m.in.Items) {
		m.cursor = 0
	}
}

func (m *flowModel) toggleCurrent() {
	if !m.in.Multi || len(m.in.Items) == 0 {
		return
	}
	id := m.in.Items[m.cursor].ID
	m.checked[id] = !m.checked[id]
}

func (m *flowModel) activate() {
	m.done = true
	if m.focus == 1 && m.footer == 0 {
		m.back = true
	}
}

func (m flowModel) choice() string {
	if !m.in.Multi {
		if len(m.in.Items) == 0 {
			return ""
		}
		return m.in.Items[m.cursor].ID
	}
	var picked []string
	for _, item := range m.in.Items {
		if m.checked[item.ID] {
			picked = append(picked, item.ID)
		}
	}
	return strings.Join(picked, " ")
}

func (m flowModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		return m, nil
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			m.quitting = true
			return m, tea.Quit
		case "b", "esc":
			if m.in.ShowBack {
				m.back = true
				m.done = true
				return m, tea.Quit
			}
			return m, nil
		case "c":
			m.activate()
			return m, tea.Quit
		case "tab":
			if len(m.in.Items) > 0 {
				if m.focus == 0 {
					m.focus = 1
				} else {
					m.focus = 0
				}
			}
			return m, nil
		case "left", "h", "right", "l":
			if m.focus == 1 && m.in.ShowBack {
				if msg.String() == "left" || msg.String() == "h" {
					m.footer = 0
				} else {
					m.footer = 1
				}
			}
			return m, nil
		case "up", "k":
			if m.focus == 0 {
				m.moveCursor(-1)
			}
			return m, nil
		case "down", "j":
			if m.focus == 0 {
				m.moveCursor(1)
			}
			return m, nil
		case " ":
			if m.focus == 0 {
				m.toggleCurrent()
			}
			return m, nil
		case "enter":
			if m.focus == 0 && len(m.in.Items) > 0 && !m.in.Multi {
				m.activate()
				return m, tea.Quit
			}
			if m.focus == 1 {
				m.activate()
				return m, tea.Quit
			}
			m.focus = 1
			return m, nil
		}
	}
	return m, nil
}

func (m flowModel) listView() string {
	if len(m.in.Items) == 0 {
		return ""
	}
	th := appTUI.Theme
	width := clamp(m.width-8, 20, 72)
	var rows []string
	for i, item := range m.in.Items {
		mark := "  "
		if m.in.Multi {
			mark = tuiString("icon_off", "○") + " "
			if m.checked[item.ID] {
				mark = tuiString("icon_on", "◉") + " "
			}
		} else if i == m.cursor {
			mark = tuiString("icon_cursor", "▸") + " "
		}
		label := item.Label
		if item.Subtitle != "" {
			label = fmt.Sprintf("%s — %s", item.Label, item.Subtitle)
		}
		label = truncateRunes(label, width-6)
		style := lipgloss.NewStyle().Foreground(th.muted())
		if i == m.cursor && m.focus == 0 {
			style = lipgloss.NewStyle().Bold(true).Foreground(th.selected())
		}
		rows = append(rows, mark+style.Render(label))
	}
	return lipgloss.NewStyle().Width(width).Align(lipgloss.Left).
		Render(lipgloss.JoinVertical(lipgloss.Left, rows...))
}

func (m flowModel) footerView() string {
	back := strings.TrimSpace(m.in.BackLabel)
	if back == "" {
		back = tuiString("button_back", "Back")
	}
	cont := strings.TrimSpace(m.in.ContinueLabel)
	if cont == "" {
		cont = tuiString("button_continue", "Continue")
	}
	back = tuiString("icon_back", "←") + " " + back
	cont = cont + " " + tuiString("icon_continue", "⏎")
	if !m.in.ShowBack {
		return renderBorderedButton(cont, true, buttonPrimary)
	}
	backActive := m.focus == 1 && m.footer == 0
	return renderButtonRow(back, cont, backActive, buttonSecondary, buttonPrimary, 4)
}

func (m flowModel) View() string {
	w := m.width
	if w < 40 {
		w = 40
	}
	h := m.height
	if h < 16 {
		h = 16
	}
	th := appTUI.Theme

	header := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(w).
		Foreground(th.accent()).Render(strings.TrimSpace(m.in.Title))
	var parts []string
	parts = append(parts, header)
	if s := strings.TrimSpace(m.in.Subtitle); s != "" {
		parts = append(parts, lipgloss.NewStyle().Align(lipgloss.Center).Width(w).
			Foreground(th.muted()).Render(s))
	}
	if s := strings.TrimSpace(m.in.Message); s != "" {
		parts = append(parts, "", lipgloss.NewStyle().Align(lipgloss.Center).Width(w).
			Foreground(th.muted()).Render(s))
	}
	if s := strings.TrimSpace(m.in.Body); s != "" {
		parts = append(parts, "", lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).BorderForeground(th.accent()).
			Padding(1, 2).MaxWidth(min(w-10, 76)).Align(lipgloss.Left).
			Foreground(th.body()).Render(s))
	}
	if list := m.listView(); list != "" {
		parts = append(parts, "", list)
	}
	parts = append(parts, "", m.footerView())

	hint := tuiString("flow_hint", "↑↓ move · Tab footer · Enter continue · b back · q quit")
	if m.in.Multi {
		hint = tuiString("flow_hint_multi", "↑↓ move · Space toggle · Tab footer · Enter continue · b back · q quit")
	}
	parts = append(parts, "", lipgloss.NewStyle().Align(lipgloss.Center).Width(w).
		Foreground(th.muted()).Render(hint))

	content := lipgloss.JoinVertical(lipgloss.Center, parts...)
	if m.in.Banner != nil {
		content = lipgloss.JoinVertical(lipgloss.Center, renderBanner(w, *m.in.Banner), "", content)
	}
	if s := renderStep(w, m.in.Step, m.in.Total); s != "" {
		content = lipgloss.JoinVertical(lipgloss.Center, s, "", content)
	}
	return lipgloss.Place(w, h, lipgloss.Center, lipgloss.Top, content)
}

func loadFlowInput(path string) (flowInput, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return flowInput{}, err
	}
	var in flowInput
	if err := json.Unmarshal(raw, &in); err != nil {
		return flowInput{}, err
	}
	return in, nil
}

func runFlowPicker(inputPath, outputPath string) error {
	in, err := loadFlowInput(inputPath)
	if err != nil {
		return err
	}
	m := flowModel{
		in:      in,
		checked: map[string]bool{},
		focus:   0,
		footer:  1,
	}
	if len(in.Items) == 0 {
		m.focus = 1
	}
	for i, item := range in.Items {
		if item.ID == in.DefaultID {
			m.cursor = i
		}
	}
	p := tea.NewProgram(m, tea.WithAltScreen())
	final, err := p.Run()
	if err != nil {
		return err
	}
	fm := final.(flowModel)
	if fm.quitting && !fm.done {
		os.Exit(1)
	}
	out := flowOutput{Choice: fm.choice(), Back: fm.back}
	dest, err := openOutput(outputPath)
	if err != nil {
		return err
	}
	defer dest.Close()
	enc := json.NewEncoder(dest)
	enc.SetIndent("", "  ")
	return enc.Encode(out)
}
