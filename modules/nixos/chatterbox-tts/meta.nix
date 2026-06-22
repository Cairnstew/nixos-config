{
  name = "chatterbox-tts";
  description = "Chatterbox TTS server — OpenAI-compatible TTS API with Web UI, multi-engine support (Original/Multilingual/Turbo), voice cloning, and large text processing";
  category = "services";
  tags = [ "tts" "ai" "audio" "sillytavern" "voice" ];
  provides = [ "my.services.chatterbox-tts" ];
  expects = [ "my.secrets" ];
  complexity = "complex";
  tested = true;
  homepage = "https://github.com/devnen/Chatterbox-TTS-Server";
  maintainer = "seanc";
}
