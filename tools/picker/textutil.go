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

// fadeText truncates long labels with a clean dim ellipsis at the end.
func fadeText(s string, maxW int) string {
	if maxW < 4 {
		return truncateRunes(s, maxW)
	}
	if runewidth.StringWidth(s) <= maxW {
		return s
	}

	body := truncateRunes(s, maxW-1)
	dimEllipsis := lipgloss.NewStyle().Foreground(lipgloss.Color("244")).Render("…")
	return body + dimEllipsis
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
	return lipgloss.NewStyle().Foreground(lipgloss.Color("255")).Render(b.String())
}

// verticalFadeColor dims top or bottom rows when more content exists outside the viewport (btop-style).
func verticalFadeColor(rowInView, viewRows, scrollOffset, totalItems int) lipgloss.Color {
	if totalItems <= viewRows || viewRows < 3 {
		return lipgloss.Color("")
	}

	itemsAbove := scrollOffset
	itemsBelow := totalItems - (scrollOffset + viewRows)

	// Top fade zone (if hidden items above)
	if itemsAbove > 0 && rowInView == 0 {
		return lipgloss.Color("240")
	}

	// Bottom fade zone (if hidden items below)
	if itemsBelow > 0 {
		distFromBottom := viewRows - 1 - rowInView
		if distFromBottom == 0 {
			return lipgloss.Color("238")
		} else if distFromBottom == 1 {
			return lipgloss.Color("244")
		}
	}

	return lipgloss.Color("")
}

func applyFadeStyle(line string, color lipgloss.Color) string {
	if color == "" {
		return line
	}
	return lipgloss.NewStyle().Foreground(color).Render(line)
}
