#if DEBUG
import CotermDebugLog

@inline(__always)
func cotermDebugLog(_ message: @autoclosure () -> String) {
    CotermDebugLog.logDebugEvent(message())
}
#endif
