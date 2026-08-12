// A mock written the way JavaScript is actually written: it pulls in a
// stylesheet purely for side effect, and re-exports a helper from another
// package. Neither line is an `import ... from`, so neither used to be
// rewritten -- bun then failed to resolve both specs from this very file.

import "fake-widgets/theme.css";

export { helper } from "fake-helper";

export const widget = { id: () => "w1" };
