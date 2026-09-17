public class Ganitor.Application : Adw.Application {
    public Application () {
        Object (
            application_id: Config.APP_ID,
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
    }

    protected override void activate () {
        var window = this.active_window;
        if (window == null) {
            window = new Ganitor.Window (this);
        }
        window.present ();
    }
}
