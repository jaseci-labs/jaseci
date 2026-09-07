export const state = {pending: [], dropped: [], env: null};
let next = 0;
export function set_na_env(name, shim, imports) {
  state.env = imports.env;
  shim.exports = {
    frame: () => {
      if (state.failFrame) throw new Error('frame failure');
      return 0;
    },
    shutdown: game => state.dropped.push(game),
    get_score: () => 12n,
    get_hp: () => 95,
    get_deaths: () => 3n,
  };
}
export function __na_bind() {
  return {init: () => new Promise(resolve => {
    const game = ++next;
    state.pending.push(() => resolve(game));
  })};
}
