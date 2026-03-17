import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// ---------------------------------------------------------------------------
// CregFaceApp — Application entry point
//
// Wires CregFaceView (the WatchFace) together with CregFaceDelegate
// (the WatchFaceDelegate). The delegate must be registered so that
// onPowerBudgetExceeded() is reachable by the runtime.
// ---------------------------------------------------------------------------

class CregFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view + delegate pair.
    // The Array must be [ WatchFace, WatchFaceDelegate ] in that order.
    function getInitialView() as [ WatchUi.Views ] or [ WatchUi.Views, WatchUi.InputDelegates ] {
        return [ new CregFaceView(), new CregFaceDelegate() ];
    }
}