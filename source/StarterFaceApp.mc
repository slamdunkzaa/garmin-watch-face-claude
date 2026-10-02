import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class StarterFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new StarterFaceView() ];
    }

}

function getApp() as StarterFaceApp {
    return Application.getApp() as StarterFaceApp;
}
