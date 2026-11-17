package main

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func testFlowModel() flowModel {
	return flowModel{
		in: flowInput{
			Title:    "Session type",
			Step:     4,
			Total:    6,
			ShowBack: true,
			Items: []flowItem{
				{ID: "de", Label: "GNOME"},
				{ID: "wm", Label: "i3"},
			},
		},
		checked: map[string]bool{},
		footer:  1,
	}
}

func TestFlowEnterSelectsFocusedItem(t *testing.T) {
	m := testFlowModel()
	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	got := next.(flowModel)
	if !got.done || got.back || got.choice() != "de" {
		t.Fatalf("enter: done=%v back=%v choice=%q", got.done, got.back, got.choice())
	}
}

func TestFlowBKeyGoesBack(t *testing.T) {
	m := testFlowModel()
	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'b'}})
	got := next.(flowModel)
	if !got.done || !got.back {
		t.Fatalf("b: done=%v back=%v", got.done, got.back)
	}
}

func TestFlowDownMovesCursor(t *testing.T) {
	m := testFlowModel()
	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyDown})
	got := next.(flowModel)
	if got.cursor != 1 {
		t.Fatalf("down: cursor=%d", got.cursor)
	}
}

func TestFlowStepRendering(t *testing.T) {
	if s := renderStep(80, 4, 6); !strings.Contains(s, "Step 4 / 6") {
		t.Fatalf("step line missing: %q", s)
	}
	if s := renderStep(80, 0, 0); s != "" {
		t.Fatalf("empty step should render nothing: %q", s)
	}
}
