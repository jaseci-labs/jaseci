glob _BUN_STORE_NOTE: str = (
         'BunStore persists through Bun.sql against the shared anchors schema'
     ),
     _BUN_SQL_API: str = 'Bun.sql';


impl BunStore.postinit -> None {
    self._ready = False;
    self._sql = None;
}
