import pukan;
static import dsdl;
import std.logger;
import std.stdio;
import std.string: toStringz;

enum fps = 60;
enum width = 640;
enum height = 640;

//~ struct Clock
//~ {
    //~ float start_time;
    //~ float elapsed;
//~ }

//~ Clock getClock()
//~ {
	//~ Clock r;
	//~ r.el
	//~ GetTime
//~ }

void main() {
    version(none)
    version(linux)
    version(DigitalMars)
    {
        import etc.linux.memoryerror;
        registerMemoryAssertHandler();
    }

	immutable name = "D/pukan3D/Raylib project";

    dsdl.loadSO();
    dsdl.init(everything: true);

    auto window = new dsdl.Window(
        name,
        [
            dsdl.WindowPos.undefined,
            dsdl.WindowPos.undefined,
        ],
        [800, 600],
        openGL: true,
        resizable: true
    );

    window.minimumSize = [400, 300];
    auto renderer = new dsdl.Renderer(window, accelerated : true, presentVSync : true);

    static auto getLogger() => stdThreadLocalLog();
    auto vk = new Backend!(getLogger)(name, makeApiVersion(1,2,3,4));
    scope(exit) destroy(vk);
    vk.printAllAvailableLayers();

    debug auto dbg = vk.attachFlightRecorder();
    debug scope(exit) destroy(dbg);

    bool running = true;
    while (running) {
        dsdl.pumpEvents();
        while (auto event = dsdl.pollEvent())
        {
            // On quit
            if (cast(dsdl.QuitEvent) event) {
                running = false;
            }
        }

        // Clears the screen with white
        renderer.drawColor = dsdl.Color(255, 255, 255);
        renderer.clear();

        // Draws a filled red box at the center of the screen
        renderer.drawColor = dsdl.Color(255, 0, 0);
        renderer.fillRect(dsdl.Rect(350, 250, 100, 100));

        renderer.present();
    }

    dsdl.quit();
}
