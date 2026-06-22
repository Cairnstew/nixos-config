// ============================================================================
// Impact Library  —  by Seraph
//
// Plugin-like interop system. Provides an event bus and callback
// registration for cross-mod communication.
//
// Integration pattern: Mod.Call
// ============================================================================
//
// USAGE:
//   1. Uncomment the block below.
//   2. Register/deregister for events using string keys.
//
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class ImpactLibraryIntegration
{
    private static Mod _impact;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("ImpactLibrary", out _impact))
            return;
    }

    /// <summary>Register a callback for an event.</summary>
    public static void On(string eventName, System.Action callback)
    {
        _impact?.Call("On", eventName, callback);
    }

    /// <summary>Register a typed callback.</summary>
    public static void On<T>(string eventName, System.Action<T> callback)
    {
        _impact?.Call("On", eventName, callback);
    }

    /// <summary>Emit an event.</summary>
    public static void Emit(string eventName, params object[] args)
    {
        _impact?.Call("Emit", eventName, args);
    }

    /// <summary>Remove a callback.</summary>
    public static void Off(string eventName, System.Action callback)
    {
        _impact?.Call("Off", eventName, callback);
    }
}
*/
