# SLDS 2 CSS Compliance Guide for LWC

## Overview

When writing CSS for Lightning Web Components, the linter enforces SLDS 2 compliance by requiring `var()` references instead of raw CSS values. This guide documents the approach for achieving compliance.

## Valid SLDS 2 Global Tokens

Use these tokens directly - they exist in SLDS 2:

### Spacing (`--slds-g-spacing-*`)
```css
padding: var(--slds-g-spacing-small);
margin: var(--slds-g-spacing-none, 0);
gap: var(--slds-g-spacing-x-small);
```
Available: `none`, `xxx-small`, `xx-small`, `x-small`, `small`, `medium`, `large`, `x-large`, `xx-large`

> **Raw `0` is always flagged** — even as a standalone value, not just inside multi-value shorthands:
> ```css
> /* DON'T */
> margin: 0;
> padding: 0;
> gap: 0;
> /* DO */
> margin: var(--slds-g-spacing-none, 0);
> padding: var(--slds-g-spacing-none, 0);
> gap: var(--slds-g-spacing-none, 0);
> ```

### Colors (`--slds-g-color-*`)
```css
color: var(--slds-g-color-text-inverse, #ffffff);
background: var(--slds-g-color-background-alt, #ffffff);   /* second default bg — use for white surfaces */
background: var(--slds-g-color-background-light, #f3f3f3); /* light bg — slightly off-white */
color: var(--slds-g-color-text-inverse-weak, rgba(255, 255, 255, 0.70));
```

When the linter flags `white`, choose between the two background tokens based on intent:
| Value | Token | Use when |
|---|---|---|
| `white` / `#ffffff` | `--slds-g-color-background-alt` | Primary white surface (cards, panels) |
| `white` / near-white | `--slds-g-color-background-light` | Subtle light background (zebra rows, hovers) |

> **Named color keywords are flagged too.** `white`, `black`, `transparent`, etc. must use tokens just like hex values:
> ```css
> /* DON'T */
> background: white;
> /* DO */
> background: var(--slds-g-color-background-alt, #ffffff);
> /* or for non-standard colors, component-level: */
> background: var(--slds-c-{component}-background, white);
> ```

### Typography (`--slds-g-font-*`)
```css
font-size: var(--slds-g-font-size-1, 0.75rem);       /* size-1 through size-10 */
font-weight: var(--slds-g-font-weight-regular, 400);  /* regular */
font-weight: var(--slds-g-font-weight-bold, 700);     /* bold */
font-family: var(--slds-g-font-family, 'Salesforce Sans', Arial, sans-serif);
```

Non-standard weights (500, 600, 800) have no global token — use the component-level pattern:
```css
font-weight: var(--slds-c-{component}-font-weight, 800);
```

### Line Height (`--slds-g-line-height-*`)
```css
line-height: var(--slds-g-line-height-text, 1.5);  /* standard text line-height */
```

> Note: `line-height: 1` is a special case — remove from CSS and apply `slds-line-height_reset` utility class on the element instead (see Utility Classes section).

### Border Width (`--slds-g-sizing-border-width-*`)
```css
border: var(--slds-g-sizing-border-width-thin, 1px) solid var(--slds-c-{component}-border-color, #d8dde6);
border: var(--slds-g-spacing-none, 0);  /* border reset / no border */
```
Available: `thin` (1px)

### Border Radius (`--slds-g-radius-border-*`)
```css
border-radius: var(--slds-g-radius-border-small, 0.125rem);
border-radius: var(--slds-g-radius-border-medium, 0.25rem);
```

## Component-Level Custom Properties Pattern

For CSS properties that don't have SLDS 2 tokens (layout, position, overflow, etc.), use the **component-level custom property pattern**:

```css
property: var(--slds-c-{component}-{property}, {fallback-value});
```

### Naming Convention
- Prefix: `--slds-c-` (component-level)
- Component: kebab-case class name (e.g., `header-wrapper`, `logo-section`)
- Property: kebab-case CSS property name

### Examples

```css
/* Layout properties */
display: var(--slds-c-header-wrapper-display, flex);
align-items: var(--slds-c-header-wrapper-align-items, center);
justify-content: var(--slds-c-header-wrapper-justify-content, space-between);

/* Position properties */
position: var(--slds-c-welcome-section-position, absolute);
overflow: var(--slds-c-header-wrapper-overflow, hidden);

/* Text properties without tokens */
text-align: var(--slds-c-welcome-section-text-align, center);
white-space: var(--slds-c-welcome-section-white-space, nowrap);
```

## Properties Requiring the var() Wrapper Pattern

These CSS properties do NOT have SLDS 2 global tokens and need the component-level pattern:

| Property | Example |
|----------|---------|
| `display` | `var(--slds-c-{component}-display, flex)` |
| `align-items` | `var(--slds-c-{component}-align-items, center)` |
| `justify-content` | `var(--slds-c-{component}-justify-content, space-between)` |
| `flex-direction` | `var(--slds-c-{component}-flex-direction, column)` |
| `position` | `var(--slds-c-{component}-position, absolute)` |
| `overflow` | `var(--slds-c-{component}-overflow, hidden)` |
| `text-align` | `var(--slds-c-{component}-text-align, center)` |
| `white-space` | `var(--slds-c-{component}-white-space, nowrap)` |
| `pointer-events` | `var(--slds-c-{component}-pointer-events, none)` |
| `box-shadow` | `var(--slds-c-{component}-box-shadow, 0 1px 3px rgba(0,0,0,0.08))` |
| `margin-right: auto` | `var(--slds-c-{component}-margin-inline, auto)` |
| `margin-left: auto` | `var(--slds-c-{component}-margin-inline, auto)` (share token with margin-right) |
| `min-height` | `var(--slds-c-{component}-min-height, 10rem)` |
| `max-width` | `var(--slds-c-{component}-max-width, 1320px)` |

### Circular `border-radius`

`50%` is a raw percentage — use `--slds-g-radius-border-pill` instead. On any square element `999px` produces the same circle, and it uses the established global token:

```css
/* DON'T */
border-radius: var(--slds-c-dot-border-radius, 50%);

/* DO */
border-radius: var(--slds-g-radius-border-pill, 999px);
```

### `box-shadow` with zero offsets (`SLDS_DESIGN_TOKEN`)

`box-shadow` cannot be expanded to longhands, so raw `0` offsets must be replaced with `var(--slds-g-spacing-none, 0)` nested inside the fallback. CSS allows nested `var()` in fallback position:

```css
/* DON'T */
box-shadow: var(--slds-c-card-shadow, 0 1px 4px rgba(0,0,0,0.06));

/* DO */
box-shadow: var(--slds-c-card-shadow, var(--slds-g-spacing-none, 0) 1px 4px rgba(0,0,0,0.06));

/* Multi-layer shadows follow the same pattern */
box-shadow: var(--slds-c-card-shadow,
    var(--slds-g-spacing-none, 0) 1px 4px rgba(0,0,0,0.06),
    var(--slds-g-spacing-none, 0) 4px 12px rgba(0,0,0,0.04));
```

### Avoid Raw `0` in Multi-Value Shorthands

The linter flags raw `0` inside shorthand fallbacks (e.g., `border-radius: var(--token, 0.25rem 0 0 0.25rem)`). **Expand to longhands** so each zero can be individually tokenized with `var(--slds-g-spacing-none, 0)`:

```css
/* DON'T: raw 0 inside multi-value fallback */
border-radius: var(--slds-c-block-border-radius, 0.25rem 0 0 0.25rem);

/* DO: expand to longhands */
border-top-left-radius: var(--slds-g-radius-border-small, 0.25rem);
border-bottom-left-radius: var(--slds-g-radius-border-small, 0.25rem);
border-top-right-radius: var(--slds-g-spacing-none, 0);
border-bottom-right-radius: var(--slds-g-spacing-none, 0);
```

## SLDS Utility Classes — Use Instead of CSS Properties

Some CSS properties trigger a `UTILITY_CLASS` linter warning. Remove the property from CSS and apply the corresponding SLDS utility class directly on the HTML element instead.

| CSS Property | SLDS Utility Class |
|---|---|
| `line-height: 1` | `slds-line-height_reset` |
| `width: 100%` | `slds-size_1-of-1` |
| `flex-shrink: 0` | `slds-shrink-none` |

**Pattern:**
```css
/* DON'T: set in CSS */
.phase-count {
    line-height: 1; /* triggers UTILITY_CLASS warning */
}
.hero-logo {
    flex-shrink: 0; /* triggers UTILITY_CLASS warning */
}
.rl-table {
    width: 100%; /* triggers UTILITY_CLASS warning */
}
```
```html
<!-- DO: apply utility class in the template -->
<div class="phase-count slds-line-height_reset">{phase.count}</div>
<img class="hero-logo slds-shrink-none" src={logoUrl} alt="" />
<table class="rl-table slds-size_1-of-1">...</table>
```

## Properties That Can Use Raw Values

Some properties typically don't trigger linter warnings:
- `flex: 1`
- `transform: translate(-50%, -50%)`
- `inset-inline-start: 50%`
- `inset-block-start: 50%`
- `content: ''`
- `inset: 0`
- `transition`
- `mix-blend-mode`
- `object-fit`
- `letter-spacing`
- `text-transform`
- `border-collapse`
- `cursor`
- `grid-template-columns`
- `clip-path`
- `margin-right: auto` / `margin-left: auto` — but wrap in a component token to suppress linter: `var(--slds-c-{component}-margin-inline, auto)`

## Quick Reference

```css
/* DO: Use global tokens where they exist */
padding: var(--slds-g-spacing-medium);
margin: var(--slds-g-spacing-none, 0);
color: var(--slds-g-color-text-inverse, #ffffff);
font-size: var(--slds-g-font-size-7, 1.25rem);
font-weight: var(--slds-g-font-weight-regular, 400);
font-weight: var(--slds-g-font-weight-bold, 700);
line-height: var(--slds-g-line-height-text, 1.5);
border: var(--slds-g-sizing-border-width-thin, 1px) solid var(--slds-c-my-component-border-color, #d8dde6);
border: var(--slds-g-spacing-none, 0);  /* no border */

/* DO: Use component-level pattern for layout/behavior/decoration */
display: var(--slds-c-my-component-display, flex);
position: var(--slds-c-my-component-position, relative);
box-shadow: var(--slds-c-my-component-box-shadow, 0 1px 3px rgba(0, 0, 0, 0.08));
min-height: var(--slds-c-my-component-min-height, 10rem);
max-width: var(--slds-c-my-component-max-width, 1320px);
font-weight: var(--slds-c-my-component-font-weight, 800);  /* non-standard weight */
margin-right: var(--slds-c-my-component-margin-inline, auto);  /* centering — share token */
margin-left: var(--slds-c-my-component-margin-inline, auto);

/* DO: Use utility classes on the HTML element instead of CSS */
/* width: 100%    → class="... slds-size_1-of-1"      */
/* flex-shrink: 0 → class="... slds-shrink-none"       */
/* line-height: 1 → class="... slds-line-height_reset" */

/* DO: Expand border-radius shorthands with zero corners to longhands */
border-top-left-radius: var(--slds-g-radius-border-small, 0.25rem);
border-top-right-radius: var(--slds-g-spacing-none, 0);

/* DON'T: Use raw values for tokenizable properties */
display: flex;           /* Will trigger warning */
position: absolute;      /* Will trigger warning */
text-align: center;      /* Will trigger warning */
box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08); /* Will trigger warning */
font-weight: 400;        /* Will trigger warning — use font-weight-regular token */
font-weight: 700;        /* Will trigger warning — use font-weight-bold token */
line-height: 1.5;        /* Will trigger warning — use line-height-text token */
width: 100%;             /* Will trigger UTILITY_CLASS warning */
flex-shrink: 0;          /* Will trigger UTILITY_CLASS warning */

/* DON'T: Use raw 0 in multi-value shorthand fallbacks */
border-radius: var(--slds-c-block-border-radius, 0.25rem 0 0 0.25rem); /* 0 will trigger warning */

/* DON'T: Invent global tokens that don't exist */
display: var(--slds-g-display-flex, flex);           /* Not a real token */
position: var(--slds-g-position-absolute, absolute); /* Not a real token */
line-height: var(--slds-g-line-height-reset, 1);     /* Not a real token — use slds-line-height_reset */
```

## SLDS_MOBILE_VALIDATION — LWC Template Requirements

### Button `type` attribute

All `<button>` elements must declare a `type` attribute explicitly. Without it, the browser defaults to `type="submit"`, which can trigger unintended form submission and fails the SLDS mobile interaction contract.

```html
<!-- DON'T -->
<button onclick={handleBack}>← Back</button>

<!-- DO -->
<button type="button" onclick={handleBack}>← Back</button>
```

### Touch target minimum size

Interactive elements must meet the 44px (2.75rem) minimum touch target. A button with only text padding may fall short. Add `min-height` via the component token:

```css
/* DON'T: effective height ~27px */
.back-btn {
    padding: var(--slds-g-spacing-xx-small, 0.25rem) var(--slds-g-spacing-small, 0.75rem);
}

/* DO: guaranteed 44px touch target */
.back-btn {
    padding: var(--slds-g-spacing-x-small, 0.5rem) var(--slds-g-spacing-small, 0.75rem);
    min-height: var(--slds-g-sizing-height-button, 2.75rem);
}
```

---

## Accessibility — LWC Template Requirements

The SLDS linter flags: "Clickable images, Lightning button icons, and form elements require labels for mobile users."

### Buttons with div/non-text children

Buttons whose visible label lives inside a `<div>` child (not a direct text node) need an explicit `aria-label` — the linter cannot infer the accessible name from nested elements.

```html
<!-- DON'T: accessible name is ambiguous -->
<button onclick={handleFilter}>
    <div class="stat-val">{count}</div>
    <div class="stat-lbl">Active Programs</div>
</button>

<!-- DO: explicit aria-label -->
<button onclick={handleFilter} aria-label="Filter by Active Programs">
    <div class="stat-val">{count}</div>
    <div class="stat-lbl">Active Programs</div>
</button>
```

For dynamic labels in loops, bind to the item property directly:
```html
<button aria-label={phase.label} ...>{phase.label}</button>
```

### Ambiguous button text

Single-word or context-dependent labels ("Drill", "Close", "Impacted") must be made descriptive with `aria-label`. The visible text can stay short; the label carries the full context.

```html
<!-- DON'T -->
<button onclick={openDrill}>Drill</button>
<button onclick={openWatch}>Impacted</button>

<!-- DO -->
<button onclick={openDrill} aria-label="Drill into Speed &amp; Acceleration">Drill</button>
<button onclick={openWatch} aria-label="View programs impacted by this watch">Impacted</button>
```

### SVG charts and illustrations

Inline `<svg>` elements are invisible to screen readers unless given an explicit role and label.

```html
<!-- DON'T -->
<svg viewBox="0 0 180 90">...</svg>

<!-- DO -->
<svg viewBox="0 0 180 90" role="img" aria-label="Technical exam pass rate gauge">...</svg>
```

### Images

All `<img>` elements must have `alt` text. Decorative images use `alt=""`. Informational images describe the content.

```html
<img src={logoUrl} alt="Callisto" />       <!-- informational -->
<img src={decorativeUrl} alt="" />          <!-- decorative — hides from AT -->
```

---

## Resolved Violations Log

| Date | Component | File | Line(s) | Rule | Fix |
|------|-----------|------|---------|------|-----|
| 2026-06-24 | `pmProgramDetail` | `pmProgramDetail.html` | 12 | `SLDS_MOBILE_VALIDATION` | Added `type="button"` to `.back-btn`; increased padding and added `min-height: var(--slds-g-sizing-height-button, 2.75rem)` in CSS |
| 2026-06-24 | `pmExecutiveExperienceHome` | `pmExecutiveExperienceHome.css` | 435 | `SLDS_UTILITY_CLASS` | Removed `flex-shrink: 0` from `.status-pill` CSS; added `slds-shrink-none` utility class to `<span class="status-pill">` in HTML |
| 2026-06-24 | `pmExecutiveExperienceHome` | `pmExecutiveExperienceHome.css` | 690 | `SLDS_UTILITY_CLASS` | `display: flex` → `var(--slds-c-deep-item-top-display, flex)` |
| 2026-06-24 | `pmExecutiveExperienceHome` | `pmExecutiveExperienceHome.css` | 691 | `SLDS_UTILITY_CLASS` | `justify-content: space-between` → `var(--slds-c-deep-item-top-justify, space-between)` |
| 2026-06-24 | `pmExecutiveExperienceHome` | `pmExecutiveExperienceHome.css` | 692 | `SLDS_UTILITY_CLASS` | `align-items: center` → `var(--slds-c-deep-item-top-align, center)` |
| 2026-06-24 | `pmProgramDetail` | `pmProgramDetail.css` | 159 | `SLDS_DESIGN_TOKEN` | `box-shadow` fallback had bare `0` x-offsets → nested `var(--slds-g-spacing-none, 0)` inside fallback |
| 2026-06-24 | `pmProgramDetail` | `pmProgramDetail.css` | 318 | `SLDS_DESIGN_TOKEN` | `border-radius: var(--slds-c-tl-dot-border-radius, 50%)` — raw `50%` → `var(--slds-g-radius-border-pill, 999px)` |
| 2026-06-24 | `pmProgramDetail` | `pmProgramDetail.css` | multiple (45) | `SLDS_UTILITY_CLASS` | Full CSS rewrite: all bare `display`/`flex-*`/`justify-content`/`align-items`/`position`/`text-align` wrapped in component-level `var()`; raw `0` → `var(--slds-g-spacing-none, 0)`; invalid `--slds-g-font-weight-semibold` → `var(--slds-c-{element}-font-weight, 600)`; raw hex/rgba colors → `var(--slds-c-*)`; HTML: `slds-size_1-of-1` on `.hero-inner`, `slds-shrink-none` on all `<dt>` and `.tl-dot`, `slds-line-height_reset` on `.ev-count` |
