export async function resolve(specifier, context, nextResolve) {
  if (specifier === "@hotwired/stimulus") {
    return {
      url: new URL("./stimulus_stub.js", import.meta.url).href,
      shortCircuit: true
    }
  }

  return nextResolve(specifier, context)
}
