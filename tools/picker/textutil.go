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

// fadeText truncates long labels with a dimming tail (no wrap).
func fadeText(s string, maxW int) string {
	if maxW < 4 {
		return truncateRunes(s, maxW)
	}
	if runewidth.StringWidth(s) <= maxW {
		return s
	}

	plain := truncateRunes(s, maxW-1) + "…"
	runes := []rune(plain)
	if len(runes) < 4 {
		return lipgloss.NewStyle().Foreground(lipgloss.Color("245")).Render(plain)
	}

	n := len(runes)
	var b strings.Builder
	fadeStyles := []lipgloss.Color{"252", "245", "240", "238"}
	for i, r := range runes {
		ch := string(r)
		fromEnd := n - 1 - i
		if fromEnd < len(fadeStyles) {
			b.WriteString(lipgloss.NewStyle().Foreground(fadeStyles[fromEnd]).Render(ch))
		} else {
			b.WriteString(ch)
		}
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
	return b.String()
}
