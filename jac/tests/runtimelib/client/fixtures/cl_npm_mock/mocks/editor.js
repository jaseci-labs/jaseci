// Behaving mock for the `fake-editor` npm package.
//
// The universal Proxy stub makes imports inert; this returns real values and
// records what it was called with, which is what a test suite actually needs
// to assert against.

const priorities = [];

export const editor = {
  showQuickPick: async (items) => items[items.length - 1],

  createStatusBarItem: (align, priority) => {
    priorities.push(priority);
    return { text: "", show() {}, dispose() {} };
  },
};

export function recordedPriorities() {
  return priorities;
}
