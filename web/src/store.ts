import { useSyncExternalStore } from 'react'

/** A tiny observable: `s` is replaced, never mutated, on every change. */
export class Store<S extends object> {
  s: S
  private listeners = new Set<() => void>()

  constructor(initial: S) {
    this.s = initial
  }

  subscribe = (listener: () => void) => {
    this.listeners.add(listener)
    return () => { this.listeners.delete(listener) }
  }

  get = () => this.s

  protected set(patch: Partial<S>) {
    this.s = { ...this.s, ...patch }
    this.listeners.forEach((l) => l())
  }
}

/** Re-renders the component whenever the store changes. */
export function useStore<S extends object>(store: Store<S>): S {
  return useSyncExternalStore(store.subscribe, store.get)
}

export const sleep = (seconds: number) => new Promise<void>((resolve) => setTimeout(resolve, seconds * 1000))
