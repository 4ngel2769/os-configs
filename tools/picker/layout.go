package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

type bannerInfo struct {
	DistroLabel   string `json:"distro_label"`
	DistroColor   string `json:"distro_color"`
	PlatformLabel string `json:"platform_label"`
	GPULabel      string `json:"gpu_label,omitempty"`
	ShowGPU       bool   `json:"show_gpu"`
}

func renderBanner(width int, b bannerInfo) string {
	if width < 40 {
		width = 40
	}
	title := lipgloss.NewStyle().Bold(true).Align(lipgloss.Center).Width(width).Render("os-configs")
	sub := lipgloss.NewStyle().Align(lipgloss.Center).Width(width).Foreground(lipgloss.Color("245")).Render("Post-install setup")
	div := lipgloss.NewStyle().Align(lipgloss.Center).Width(width).Foreground(lipgloss.Color("240")).Render(strings.Repeat("─", clamp(width-4, 20, 100)))

	badgeColor := lipgloss.Color("252")
	if b.DistroColor != "" {
		badgeColor = lipgloss.Color(b.DistroColor)
	}
	badge := lipgloss.NewStyle().Align(lipgloss.Center).Width(width).Foreground(badgeColor).
		Render(fmt.Sprintf("/ %s · %s \\", b.DistroLabel, b.PlatformLabel))

	lines := []string{title, sub, div, badge, div}
	if b.ShowGPU && b.GPULabel != "" {
		gpu := lipgloss.NewStyle().Align(lipgloss.Center).Width(width).Render(fmt.Sprintf("GPU: %s", b.GPULabel))
		lines = append(lines, gpu, div)
	}
	return lipgloss.JoinVertical(lipgloss.Center, lines...)
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
