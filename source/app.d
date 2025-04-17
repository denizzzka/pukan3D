import pukan;
import bindbc.sdl;
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

    static auto getLogger() => stdThreadLocalLog();
    auto vk = new Backend!(getLogger)(name, makeApiVersion(1,2,3,4));
    scope(exit) destroy(vk);

    dsdl.loadSO();
    dsdl.init(everything: true);

    auto sdl_window = SDL_CreateWindow(
        name.toStringz,
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        640, 360,
        SDL_WINDOW_SHOWN | SDL_WINDOW_VULKAN
    );

    auto window = new dsdl.Window(sdl_window, userRef: cast(void*) vk);
    auto renderer = new dsdl.Renderer(window, accelerated : true, presentVSync : true);

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
