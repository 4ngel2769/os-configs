package main

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/mattn/go-runewidth"
)

func truncateRunes(s string, maxW int) string {
	if maxW < 1 {
		return ""
	}
	out := ""
	for _, r := range s {
		next := out + string(r)
		if runewidth.StringWidth(next) > maxW {
			break
		}
		out = next
	}
	return out
}

// fadeText truncates long labels; the visible tail fades from bright to dim (→).
func fadeText(s string, maxW int) string {
	if maxW < 4 {
		return truncateRunes(s, maxW)
	}
	if runewidth.StringWidth(s) <= maxW {
		return s
	}

	plain := truncateRunes(s, maxW-1) + "…"
	runes := []rune(plain)
	if len(runes) < 3 {
		return lipgloss.NewStyle().Foreground(lipgloss.Color("245")).Render(plain)
	}

	// Bright body, last N runes dim toward the cut (btop-style horizontal fade-out).
	const fadeLen = 4
	fadeStart := len(runes) - fadeLen
	if fadeStart < 1 {
		fadeStart = 1
	}
	shades := []lipgloss.Color{"252", "245", "240", "236"}

	var b strings.Builder
	for i, r := range runes {
		ch := string(r)
		if i < fadeStart {
			b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("252")).Render(ch))
			continue
		}
		idx := i - fadeStart
		if idx >= len(shades) {
			idx = len(shades) - 1
		}
		b.WriteString(lipgloss.NewStyle().Foreground(shades[idx]).Render(ch))
	}
	return b.String()
}

// marqueeText scrolls long labels horizontally when selected.
func marqueeText(s string, maxW int, offset int) string {
	if maxW < 1 {
		return ""
	}
	if runewidth.StringWidth(s) <= maxW {
		return s
	}
	pad := "   "
	loop := s + pad
	runes := []rune(loop)
	if len(runes) == 0 {
		return ""
	}
	off := offset % len(runes)
	var b strings.Builder
	w := 0
	for i := 0; i < len(runes)*2 && w < maxW; i++ {
		r := runes[(off+i)%len(runes)]
		ch := string(r)
		cw := runewidth.StringWidth(ch)
		if w+cw > maxW {
			break
		}
		b.WriteRune(r)
		w += cw
	}
	return lipgloss.NewStyle().Foreground(lipgloss.Color("252")).Render(b.String())
}

// verticalFadeColor dims rows near the bottom when more content exists below.
func verticalFadeColor(rowInView, viewRows, rowsBelow int) lipgloss.Color {
	if rowsBelow <= 0 || viewRows < 2 {
		return lipgloss.Color("")
	}
	fadeZone := 3
	if fadeZone > viewRows {
		fadeZone = viewRows
	}
	distFromBottom := viewRows - 1 - rowInView
	if distFromBottom >= fadeZone {
		return lipgloss.Color("")
	}
	shades := []lipgloss.Color{"245", "240", "236", "234"}
	idx := fadeZone - 1 - distFromBottom
	if idx < 0 {
		idx = 0
	}
	if idx >= len(shades) {
		idx = len(shades) - 1
	}
	return shades[idx]
}

func applyFadeStyle(line string, color lipgloss.Color) string {
	if color == "" {
		return line
	}
	return lipgloss.NewStyle().Foreground(color).Render(line)
}
