package com.airswipe.air_swipe

/**
 * AIDL stub that runs inside Shizuku's UserService process and executes commands as the
 * shell (adb) uid.
 *
 * - WARNING: this executes the raw command array it is given, with shell privileges, so callers
 *   must never pass user-controlled strings (only fixed literals plus validated numeric args).
 * - Whenever this service's code changes, bump `.version(n)` in `ShizukuSwipeExecutor`'s
 *   `Shizuku.UserServiceArgs` so Shizuku restarts the daemon.
 */
class ShellExecutorService : IShellExecutor.Stub() {
    override fun exec(command: Array<String>) {
        Runtime.getRuntime().exec(command)
    }
}
