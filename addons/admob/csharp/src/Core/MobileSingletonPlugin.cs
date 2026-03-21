// MIT License
// Copyright (c) 2023-present Poing Studios

using Godot;

namespace PoingStudios.AdMob.Core
{
	public class MobileSingletonPlugin
	{
		protected static GodotObject GetPlugin(string pluginName, bool isRequired = true)
		{
			if (Engine.HasSingleton(pluginName))
			{
				return Engine.GetSingleton(pluginName);
			}

			string osName = OS.GetName();
			if (osName != "Android" && osName != "iOS")
			{
				return null;
			}

			string location = osName == "Android" 
				? "'res://addons/admob/android/config.gd' and 'Use Gradle Build' is enabled" 
				: "the 'Plugins' section of the Export tab";
			
			string message = $"{pluginName} not found, make sure it is enabled in {location}";

			if (isRequired)
			{
				GD.PrintErr(message);
			}
			else
			{
				GD.PushWarning(message);
			}

			return null;
		}

		protected static void SafeConnect(GodotObject plugin, string signalName, Callable callable, uint flags = 0)
		{
			if (plugin != null && !plugin.IsConnected(signalName, callable))
			{
				plugin.Connect(signalName, callable, flags);
			}
		}
	}
}
