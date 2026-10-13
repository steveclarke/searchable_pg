// searchable_pg 0.2.0: copied by `rails g searchable_pg:global_frontend`.
// Re-run the generator after upgrading the gem to see what changed.
//
// Turns a global search envelope into Nuxt UI command palette groups: the
// top hit first in a group of its own, then one group per kind under its
// heading, each with a "See all" item when the kind has more.
import type { CommandPaletteGroup, CommandPaletteItem } from "@nuxt/ui";

export type SearchItem = {
  id: string | number;
  title: string;
  subtitle: string | null;
  url: string | null;
  snippet: string | null;
};

export type SearchGroup = {
  type: string;
  label: string;
  icon: string | null;
  more: boolean;
  results: SearchItem[];
};

export type SearchEnvelope = {
  query: string;
  top_hit: { kind: string; id: string | number } | null;
  partial: boolean;
  groups: SearchGroup[];
};

export type SearchGroupsOptions = {
  topHitLabel?: string;
  // "See all People"; leave out to show no See-all item.
  seeAllLabel?: (group: SearchGroup) => string;
  seeAllUrl?: (group: SearchGroup, query: string) => string;
  // The icon when a kind has none.
  defaultIcon?: string;
  // Called with each item as it is chosen (for recent items).
  onSelect?: (group: SearchGroup, item: SearchItem) => void;
};

// A snippet arrives as escaped HTML whose only tag is <mark>. Parsed, never
// inserted, so it stays text.
export function snippetText(snippet: string | null): string | undefined {
  if (!snippet) return undefined;
  return new DOMParser().parseFromString(snippet, "text/html").body.textContent ?? undefined;
}

export function itemFor(
  group: SearchGroup,
  item: SearchItem,
  options: SearchGroupsOptions = {},
): CommandPaletteItem {
  return {
    id: `${group.type}:${item.id}`,
    label: item.title,
    description: [item.subtitle, snippetText(item.snippet)].filter(Boolean).join(" · ") || undefined,
    icon: group.icon ?? options.defaultIcon,
    to: item.url ?? undefined,
    onSelect: options.onSelect ? () => options.onSelect?.(group, item) : undefined,
  };
}

export function searchGroups(
  envelope: SearchEnvelope | null | undefined,
  options: SearchGroupsOptions = {},
): CommandPaletteGroup<CommandPaletteItem>[] {
  if (!envelope) return [];
  const hit = envelope.top_hit;
  const isHit = (group: SearchGroup, item: SearchItem) =>
    !!hit && hit.kind === group.type && hit.id === item.id;
  const groups: CommandPaletteGroup<CommandPaletteItem>[] = [];
  if (hit) {
    const group = envelope.groups.find((candidate) => candidate.type === hit.kind);
    const item = group?.results.find((candidate) => isHit(group, candidate));
    if (group && item)
      groups.push({
        id: "top-hit",
        label: options.topHitLabel ?? "Top hit",
        ignoreFilter: true,
        items: [itemFor(group, item, options)],
      });
  }
  for (const group of envelope.groups) {
    const items = group.results
      .filter((item) => !isHit(group, item))
      .map((item) => itemFor(group, item, options));
    if (group.more && options.seeAllLabel && options.seeAllUrl)
      items.push({
        id: `${group.type}:see-all`,
        label: options.seeAllLabel(group),
        icon: group.icon ?? options.defaultIcon,
        to: options.seeAllUrl(group, envelope.query),
      });
    if (items.length) groups.push({ id: `kind:${group.type}`, label: group.label, ignoreFilter: true, items });
  }
  return groups;
}
