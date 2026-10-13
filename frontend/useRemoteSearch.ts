// searchable_pg 0.2.0: copied by `rails g searchable_pg:global_frontend`.
// Re-run the generator after upgrading the gem to see what changed.
//
// Search-as-you-type against the app's global search endpoint. Waits `delay`
// ms after the last keystroke, skips terms shorter than `minLength`, and
// aborts the previous request when a new one starts, so a slow response for
// "ma" can never replace the results for "mary". `failed` says the last
// search got no answer (an error status or no connection), for callers that
// tell that apart from finding nothing. The fetch is injected: an Inertia app
// passes `fetch`; a Nuxt app passes `$fetch`-backed code with its API base
// and headers.
import { onScopeDispose, shallowRef, watch, type Ref } from "vue";

export type SearchFetch<T> = (term: string, signal: AbortSignal) => Promise<T>;

export function useRemoteSearch<T>(
  term: Ref<string>,
  fetchResults: SearchFetch<T>,
  { minLength = 2, delay = 200 }: { minLength?: number; delay?: number } = {},
) {
  const results = shallowRef<T | null>(null);
  const loading = shallowRef(false);
  const failed = shallowRef(false);
  let controller: AbortController | null = null;
  let timer: ReturnType<typeof setTimeout> | null = null;

  const abort = () => {
    controller?.abort();
    controller = null;
    if (timer) clearTimeout(timer);
    timer = null;
  };

  const run = async (value: string) => {
    abort();
    if (value.trim().length < minLength) {
      results.value = null;
      loading.value = false;
      failed.value = false;
      return;
    }
    const current = new AbortController();
    controller = current;
    loading.value = true;
    failed.value = false;
    try {
      const found = await fetchResults(value.trim(), current.signal);
      if (current.signal.aborted) return;
      results.value = found;
    } catch (error) {
      if (current.signal.aborted) return;
      results.value = null;
      failed.value = true;
    }
    loading.value = false;
  };

  // Loading from the keystroke, not only once the debounce fires, so a caller
  // never reads "nothing found" for a term it has not asked about yet.
  watch(term, (value) => {
    abort();
    results.value = null;
    failed.value = false;
    loading.value = value.trim().length >= minLength;
    timer = setTimeout(() => run(value), delay);
  });
  onScopeDispose(abort);

  const retry = () => run(term.value);
  return { results, loading, failed, retry };
}
