package {{package}}

abstract class Walker {
    val reports = mutableListOf<Any?>()

    fun report(v: Any?) {
        reports.add(v)
    }

    abstract fun onRootEntry(here: Node)

    fun spawnOn(start: Node): List<Any?> {
        onRootEntry(start)
        return reports.toList()
    }
}
