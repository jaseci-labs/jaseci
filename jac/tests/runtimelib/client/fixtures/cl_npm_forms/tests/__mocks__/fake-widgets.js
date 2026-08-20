// Side-effect import, a re-export from another package, and a helper of its
// own -- the last is not an npm package, so the harness has to stage it too.

import "fake-widgets/theme.css";

export { helper } from "fake-helper";

import { nextId } from "./support/ids";

export const widget = { id: () => nextId() };
