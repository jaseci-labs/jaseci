// A mock written the way JavaScript is actually written: it pulls in a
// stylesheet purely for side effect, and re-exports a helper from another
// package. Neither line is an `import ... from`, and both resolve because the
// generated tsconfig gives every discovered spec a target.

import "fake-widgets/theme.css";

export { helper } from "fake-helper";

export const widget = { id: () => "w1" };
