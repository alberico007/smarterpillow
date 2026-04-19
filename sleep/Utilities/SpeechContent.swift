//
//  SpeechContent.swift
//  sleep
//
//  Original scripts for TTS-backed meditations and sleep stories.
//  Keyed by SoundItem.id. When SoundService.addSound is called for a
//  sound whose id appears here, it's spoken via AVSpeechSynthesizer
//  instead of played from a bundled audio file.
//

import Foundation

enum SpeechContent {

    static func script(for id: String) -> String? {
        scripts[id]
    }

    private static let scripts: [String: String] = [

        // MARK: - Meditations

        "tts_breathing_478": """
        Let's practice the four-seven-eight breath.
        Close your eyes. Relax your shoulders.
        Breathe in quietly through your nose for four counts.
        Hold your breath for seven counts.
        Now exhale completely through your mouth for eight counts.
        Again. Breathe in — two, three, four. Hold — two, three, four, five, six, seven.
        And out — two, three, four, five, six, seven, eight.
        Keep this rhythm. With each exhale, let your body sink deeper into the bed.
        One more cycle. Breathe in. Hold. Release everything.
        Return to normal breathing. Rest here as long as you'd like.
        """,

        "tts_body_scan": """
        Lie back and let your body soften.
        Bring your attention to the top of your head. Notice any tension there, and let it melt away.
        Move down to your forehead, your jaw, your neck. Soften each one.
        Notice your shoulders. Let them drop.
        Feel your arms grow heavy. Your hands loosen. Your fingers uncurl.
        Move your awareness to your chest. Feel it rise and fall with your breath.
        Your stomach relaxes. Your lower back releases.
        Your hips settle into the bed. Your thighs, heavy. Your knees, loose.
        Your calves, soft. Your ankles, light. Your feet, still.
        You are completely relaxed from head to toe.
        Rest here, letting sleep come to you.
        """,

        "tts_progressive_relaxation": """
        We'll move through your body, tensing and releasing each muscle group.
        Start with your feet. Curl your toes tightly. Hold for five seconds.
        And release. Feel the tension drain away.
        Tighten your calves. Hold. And let go.
        Squeeze your thighs. Hold. Release.
        Clench your fists. Hold. And soften.
        Tense your arms. Hold. And release.
        Shrug your shoulders up to your ears. Hold. Drop them.
        Scrunch your face. Hold. And relax completely.
        Take a deep breath in. Hold at the top. And exhale slowly.
        Your whole body is now at ease. Let the stillness carry you toward sleep.
        """,

        "tts_gratitude": """
        Take a slow breath in, and let it out.
        Bring to mind one small thing from today that went well.
        It can be tiny. A warm cup of coffee. A kind word. A moment of quiet.
        Hold that thought. Notice how it feels in your chest.
        Now bring to mind someone you're grateful for.
        Picture their face. Silently thank them.
        Finally, find one thing about yourself you appreciate.
        Something you did. Something you endured. Something you are.
        Let that appreciation fill you.
        Carry this warmth into your sleep. You've earned this rest.
        """,

        "tts_loving_kindness": """
        Place a hand over your heart if that feels right.
        Silently repeat these words: May I be safe. May I be peaceful. May I be well. May I sleep easy.
        Now bring to mind someone you love.
        Picture them. Offer them the same wishes. May you be safe. May you be peaceful. May you be well. May you sleep easy.
        Now think of someone you barely know. A neighbor. A stranger.
        Offer them the same kindness. May you be safe. May you be peaceful. May you be well.
        Finally, extend these wishes to everyone, everywhere.
        May all beings be safe. May all beings be peaceful. May all beings rest.
        Let that kindness soften you. Drift into sleep.
        """,

        // MARK: - Sleep Stories

        "tts_story_quiet_forest": """
        Imagine a forest at dusk.
        The air is cool and still. Pine needles soften each step beneath your feet.
        You walk slowly along a narrow path. A stream murmurs somewhere to your left.
        Above, the trees form a quiet canopy. A single star appears in the gap between branches.
        You reach a clearing. Moss covers a fallen log. You sit down.
        An owl calls, far off. Then silence again.
        The forest breathes around you. You breathe with it.
        Your eyelids grow heavy. The stars multiply overhead.
        You lie back on the soft moss. The forest holds you.
        And you drift, slowly, into sleep.
        """,

        "tts_story_moonlit_beach": """
        You are standing at the edge of a quiet beach.
        The moon is full. It lays a silver path across the water.
        Small waves roll in, one after another, whispering as they reach the sand.
        You walk along the shore. The sand is cool beneath your feet.
        A breeze touches your face, carrying the scent of salt.
        You stop and look up. The sky is vast. Countless stars.
        You sit, then lie back on the soft sand. The waves keep their rhythm.
        Each wave carries a little of your tension out to sea.
        The moon watches over you. The tide is gentle.
        You close your eyes. Sleep comes in with the next wave.
        """,

        "tts_story_mountain_cabin": """
        Picture a small cabin high in the mountains.
        Snow falls softly outside the windows. Inside, a fire crackles in the hearth.
        You are wrapped in a thick blanket on a wooden chair by the fire.
        The flames dance. Embers glow orange.
        A kettle hums on the stove. The smell of woodsmoke and pine fills the room.
        Outside, the wind is a distant hush. The snow keeps falling.
        You sink deeper into the blanket. Your eyes grow heavy.
        The fire pops gently. A log shifts.
        Warm. Safe. Still.
        You let yourself drift. The mountain is quiet. The cabin holds you. Sleep is near.
        """,

        "tts_story_gentle_river": """
        You are floating on a slow, warm river.
        The water is glass-smooth. The sky above you is endless blue.
        You lie on your back in a small wooden boat. Nothing hurries.
        The river winds through meadows of wildflowers.
        A dragonfly hovers past. A willow tree brushes the water's surface.
        You hear only the soft lap of water against the boat.
        The sun is gentle, not bright. The air is warm.
        You trail one hand in the water. It is cool. Refreshing.
        The boat drifts on its own. You don't need to steer.
        The river carries you, safely, slowly, into sleep.
        """,

        "tts_story_ancient_library": """
        Imagine a grand old library, after closing time.
        You are alone. Lamps glow warmly between the tall shelves.
        The smell of old paper and leather fills the air.
        You walk slowly down an aisle of books. Each title softer to read than the last.
        At the end of the aisle, a deep armchair waits beside a window.
        Moonlight pours in, pale and silver.
        You sink into the chair. A book rests in your lap, unopened.
        The library is completely silent. Generations of stories sleep on the shelves around you.
        Your eyes grow heavy. The lamps seem to dim.
        And in the hush of all those pages, you fall asleep.
        """
    ]
}
