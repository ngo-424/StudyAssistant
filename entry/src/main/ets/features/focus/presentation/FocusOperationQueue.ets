// UI reads and commands share one queue so a delayed restore cannot overwrite a pause or finish.
export class FocusOperationQueue {
  private tail: Promise<void> = Promise.resolve()

  run<T>(operation: () => Promise<T>): Promise<T> {
    const result: Promise<T> = this.tail.then(operation)
    this.tail = result.then(() => {}, () => {})
    return result
  }
}
