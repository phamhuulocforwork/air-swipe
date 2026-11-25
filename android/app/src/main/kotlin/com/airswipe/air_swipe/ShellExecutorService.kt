package com.airswipe.air_swipe

class ShellExecutorService : IShellExecutor.Stub() {
    override fun exec(command: Array<String>) {
        Runtime.getRuntime().exec(command)
    }
}
