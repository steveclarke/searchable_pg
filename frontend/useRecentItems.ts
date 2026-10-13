// searchable_pg 0.2.0: copied by `rails g searchable_pg:global_frontend`.
// Re-run the generator after upgrading the gem to see what changed.
//
// What a person opened from search, and what they searched for, kept in this
// browser only under `search:recent:<user id>`: the last 8 items and the last
// 5 queries, newest first. Call `clear()` on sign-out so a shared computer
// never shows the last person's recents. Storage that throws (private
// windows, blocked site data) leaves the lists empty.
import { shallowRef } from "vue";

export type RecentItem = {
  kind: string;
  id: string | number;
  title: string;
  subtitle: string | null;
  url: string;
  icon: string | null;
};

type Stored = { items: RecentItem[]; queries: string[] };

export const RECENT_ITEMS = 8;
export const RECENT_QUERIES = 5;

export function recentKey(userId: string | number): string {
  return `search:recent:${userId}`;
}

function read(key: string): Stored {
  try {
    const parsed = JSON.parse(localStorage.getItem(key) ?? "null");
    if (parsed && Array.isArray(parsed.items) && Array.isArray(parsed.queries)) return parsed;
  } catch {
    // Unreadable storage counts as empty.
  }
  return { items: [], queries: [] };
}

function write(key: string, value: Stored) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Storage may be full or blocked; recents are a convenience.
  }
}

export function useRecentItems(userId: string | number) {
  const key = recentKey(userId);
  const stored = read(key);
  const items = shallowRef<RecentItem[]>(stored.items);
  const queries = shallowRef<string[]>(stored.queries);

  const save = () => write(key, { items: items.value, queries: queries.value });

  const remember = (item: RecentItem) => {
    items.value = [item, ...items.value.filter((it) => !(it.kind === item.kind && String(it.id) === String(item.id)))].slice(0, RECENT_ITEMS);
    save();
  };

  const rememberQuery = (query: string) => {
    const trimmed = query.trim();
    if (!trimmed) return;
    queries.value = [trimmed, ...queries.value.filter((it) => it.toLowerCase() !== trimmed.toLowerCase())].slice(0, RECENT_QUERIES);
    save();
  };

  const clear = () => {
    items.value = [];
    queries.value = [];
    try {
      localStorage.removeItem(key);
    } catch {
      // Nothing to clear.
    }
  };

  return { items, queries, remember, rememberQuery, clear };
}

// Every person's recents in this browser, for sign-out.
export function clearAllRecentItems() {
  try {
    for (let index = localStorage.length - 1; index >= 0; index -= 1) {
      const key = localStorage.key(index);
      if (key?.startsWith("search:recent:")) localStorage.removeItem(key);
    }
  } catch {
    // Nothing to clear.
  }
}
