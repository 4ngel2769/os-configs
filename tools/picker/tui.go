package main

import (
	"encoding/json"
	"os"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

type themeConfig struct {
	Accent             string `json:"accent"`
	Body               string `json:"body"`
	Muted              string `json:"muted"`
	Dim                string `json:"dim"`
	Success            string `json:"success"`
	Secondary          string `json:"secondary"`
	Selected           string `json:"selected"`
	DialogBorder       string `json:"dialog_border"`
	ButtonActiveBorder string `json:"button_active_border"`
	ButtonIdleBorder   string `json:"button_idle_border"`
}

type tuiFile struct {
	Strings map[string]string `json:"strings"`
	Theme   themeConfig       `json:"theme"`
}

var appTUI tuiFile

func defaultTUI() tuiFile {
	return tuiFile{
		Strings: map[string]string{
			"app_title":                 "os-configs",
			"app_subtitle":              "Post-install setup",
			"confirm_yes":               "Yes",
			"confirm_no":                "No",
			"confirm_hint":              "←/→ toggle · Enter submit",
			"button_back":               "Back",
			"button_continue":           "Continue",
			"software_hint":             "↑↓ move · Space toggle · Enter switch pane · Tab footer · c continue",
			"list_hint":                 "↑↓ move · Enter select",
			"info_continue":             "Continue",
			"info_hint":                 "Enter continue",
			"software_main_title":       "Custom software",
			"software_arco_title":       "More apps",
			"software_arco_subtitle":    "Extended catalog",
		},
		Theme: themeConfig{
			Accent:             "86",
			Body:               "252",
			Muted:              "245",
			Dim:                "240",
			Success:            "10",
			Secondary:          "117",
			Selected:           "229",
			DialogBorder:       "86",
			ButtonActiveBorder: "10",
			ButtonIdleBorder:   "240",
		},
	}
}

func loadTUI(path string) error {
	appTUI = defaultTUI()
	if path == "" {
		return nil
	}

	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}

	var loaded tuiFile
	if err := json.Unmarshal(raw, &loaded); err != nil {
		return err
	}

	for k, v := range loaded.Strings {
		if strings.TrimSpace(v) != "" {
			appTUI.Strings[k] = v
		}
	}
	mergeTheme(&appTUI.Theme, loaded.Theme)
	return nil
}

func mergeTheme(dst *themeConfig, src themeConfig) {
	if src.Accent != "" {
		dst.Accent = src.Accent
	}
	if src.Body != "" {
		dst.Body = src.Body
	}
	if src.Muted != "" {
		dst.Muted = src.Muted
	}
	if src.Dim != "" {
		dst.Dim = src.Dim
	}
	if src.Success != "" {
		dst.Success = src.Success
	}
	if src.Secondary != "" {
		dst.Secondary = src.Secondary
	}
	if src.Selected != "" {
		dst.Selected = src.Selected
	}
	if src.DialogBorder != "" {
		dst.DialogBorder = src.DialogBorder
	}
	if src.ButtonActiveBorder != "" {
		dst.ButtonActiveBorder = src.ButtonActiveBorder
	}
	if src.ButtonIdleBorder != "" {
		dst.ButtonIdleBorder = src.ButtonIdleBorder
	}
}

func tuiString(key, fallback string) string {
	if v := strings.TrimSpace(appTUI.Strings[key]); v != "" {
		return v
	}
	return fallback
}

func tuiColor(code, fallback string) lipgloss.Color {
	code = strings.TrimSpace(code)
	if code == "" {
		code = fallback
	}
	return lipgloss.Color(code)
}

func (t themeConfig) accent() lipgloss.Color   { return tuiColor(t.Accent, "86") }
func (t themeConfig) body() lipgloss.Color     { return tuiColor(t.Body, "252") }
func (t themeConfig) muted() lipgloss.Color    { return tuiColor(t.Muted, "245") }
func (t themeConfig) dim() lipgloss.Color      { return tuiColor(t.Dim, "240") }
func (t themeConfig) success() lipgloss.Color  { return tuiColor(t.Success, "10") }
func (t themeConfig) secondary() lipgloss.Color { return tuiColor(t.Secondary, "117") }
func (t themeConfig) selected() lipgloss.Color { return tuiColor(t.Selected, "229") }

// centerBlock pads every line of a multi-line block by the same amount so bordered
// JoinHorizontal rows stay aligned (Width+Align per line breaks rounded borders).
func centerBlock(termW int, block string) string {
	if termW < 1 || block == "" {
		return block
	}
	blockW := lipgloss.Width(block)
	if blockW <= 0 || blockW >= termW {
		return block
	}
	prefix := strings.Repeat(" ", (termW-blockW)/2)
	lines := strings.Split(block, "\n")
	for i, line := range lines {
		lines[i] = prefix + line
	}
	return strings.Join(lines, "\n")
}

type buttonVariant int

const (
	buttonPrimary buttonVariant = iota
	buttonSecondary
)

func renderBorderedButton(label string, active bool, variant buttonVariant) string {
	th := appTUI.Theme
	fg := th.secondary()
	border := th.ButtonIdleBorder
	if variant == buttonPrimary {
		fg = th.success()
	}
	if active {
		if variant == buttonPrimary {
			border = th.Success
		} else {
			border = th.Secondary
		}
	}

	style := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		Padding(0, 2).
		Foreground(fg).
		BorderForeground(tuiColor(border, "240"))
	if active {
		style = style.Bold(true)
	}
	return style.Render(label)
}

func renderButtonRow(leftLabel, rightLabel string, leftActive bool, leftVariant, rightVariant buttonVariant, gap int) string {
	if gap < 1 {
		gap = 3
	}
	left := renderBorderedButton(leftLabel, leftActive, leftVariant)
	right := renderBorderedButton(rightLabel, !leftActive, rightVariant)
	return lipgloss.JoinHorizontal(lipgloss.Top, left, strings.Repeat(" ", gap), right)
}

func renderButtonPair(leftLabel, rightLabel string, leftActive bool, gap int) string {
	return renderButtonRow(leftLabel, rightLabel, leftActive, buttonPrimary, buttonSecondary, gap)
}

func renderDialog(title, body, message string, buttons string, maxW int) string {
	th := appTUI.Theme
	if maxW < 32 {
		maxW = 32
	}

	var inner []string
	if strings.TrimSpace(body) != "" {
		inner = append(inner, lipgloss.NewStyle().
			Foreground(th.body()).
			Render(body))
	}
	if strings.TrimSpace(message) != "" {
		margin := 0
		if len(inner) > 0 {
			margin = 1
		}
		inner = append(inner, lipgloss.NewStyle().
			Foreground(th.muted()).
			MarginTop(margin).
			Render(message))
	}
	if strings.TrimSpace(buttons) != "" {
		margin := 1
		if len(inner) == 0 {
			margin = 0
		}
		inner = append(inner, lipgloss.NewStyle().MarginTop(margin).Render(buttons))
	}

	dialogBody := lipgloss.JoinVertical(lipgloss.Center, inner...)
	dialog := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(th.accent()).
		Padding(1, 2).
		Align(lipgloss.Center).
		MaxWidth(maxW).
		Render(dialogBody)

	titleLine := lipgloss.NewStyle().
		Bold(true).
		Foreground(th.accent()).
		Render(title)

	return lipgloss.JoinVertical(lipgloss.Center, titleLine, "", dialog)
}
