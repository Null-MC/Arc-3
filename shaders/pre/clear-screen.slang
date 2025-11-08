import aperture;
import lib.water.water_depth;


[[shader("compute")]]
[numthreads(16, 16, 1)]
void clearScreen(uint3 globalPos : SV_DispatchThreadID) {
    if (!all(globalPos.xy < ap.game.screenSize)) return;

    WaterDepth_clear(globalPos.xy);
}
