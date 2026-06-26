import { getPreviewString, saveTtsProviderSettings } from './index.js';
import { getRequestHeaders } from '../../../script.js';

export { ResembleTtsProvider };

class ResembleTtsProvider {
    settings;
    voices = [];
    separator = ' ... ';

    defaultSettings = {
        voiceMap: {},
        cluster: 'p',
        apiToken: '',
        voices: [
            { name: 'Default', voice_id: '8bc27ed9' },
        ],
    };

    get settingsHtml() {
        let html = `
        <label for="resemble_tts_cluster">Cluster:</label>
        <input id="resemble_tts_cluster" type="text" class="text_pole" maxlength="100" value="${this.defaultSettings.cluster}"/>
        <label for="resemble_tts_token">API Token:</label>
        <input id="resemble_tts_token" type="password" class="text_pole" maxlength="500" value="${this.defaultSettings.apiToken}"/>
        <label for="resemble_tts_voices">Voices (comma-separated name:uuid pairs):</label>
        <input id="resemble_tts_voices" type="text" class="text_pole" value="${this.defaultSettings.voices.map(v => `${v.name}:${v.voice_id}`).join()}"/>`;
        return html;
    }

    constructor() {
    }

    dispose() {
    }

    async loadSettings(settings) {
        if (Object.keys(settings).length == 0) {
            console.info('Using default Resemble TTS settings');
        }

        this.settings = this.defaultSettings;

        for (const key in settings) {
            if (key in this.settings) {
                this.settings[key] = settings[key];
            } else {
                throw `Invalid setting passed to Resemble TTS: ${key}`;
            }
        }

        $('#resemble_tts_cluster').val(this.settings.cluster);
        $('#resemble_tts_cluster').on('input', () => { this.onSettingsChange(); });

        $('#resemble_tts_token').val(this.settings.apiToken);
        $('#resemble_tts_token').on('input', () => { this.onSettingsChange(); });

        $('#resemble_tts_voices').val(this.settings.voices.map(v => `${v.name}:${v.voice_id}`).join());
        $('#resemble_tts_voices').on('input', () => { this.onSettingsChange(); });

        await this.checkReady();
    }

    onSettingsChange() {
        this.settings.cluster = String($('#resemble_tts_cluster').val());
        this.settings.apiToken = String($('#resemble_tts_token').val());

        const voicesStr = String($('#resemble_tts_voices').val());
        this.settings.voices = voicesStr.split(',').map(pair => {
            const parts = pair.trim().split(':');
            return { name: parts[0]?.trim() || 'Default', voice_id: parts[1]?.trim() || parts[0]?.trim() };
        }).filter(v => v.voice_id);

        saveTtsProviderSettings();
    }

    async checkReady() {
        this.voices = await this.fetchTtsVoiceObjects();
    }

    async onRefreshClick() {
        return;
    }

    async getVoice(voiceName) {
        if (this.voices.length == 0) {
            this.voices = await this.fetchTtsVoiceObjects();
        }
        // Match by name first
        const match = this.voices.filter(v => v.name == voiceName)[0];
        if (match) return match;
        // If voiceName is a UUID, return it directly
        if (/^[a-f0-9]{8}/i.test(voiceName)) {
            return { name: voiceName, voice_id: voiceName, lang: 'en-US' };
        }
        // Fall back to the first configured voice
        console.warn(`Resemble voice "${voiceName}" not found, using first available`);
        return this.voices[0];
    }

    async generateTts(text, voiceId) {
        const response = await this.fetchTtsGeneration(text, voiceId);
        return response;
    }

    async fetchTtsVoiceObjects() {
        return this.settings.voices.map(v => {
            return { name: v.name, voice_id: v.voice_id, lang: 'en-US' };
        });
    }

    async previewTtsVoice(voiceId) {
        const audioElement = document.createElement('audio');
        audioElement.pause();
        audioElement.currentTime = 0;

        const text = getPreviewString('en-US');
        const response = await this.fetchTtsGeneration(text, voiceId);
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const audio = await response.blob();
        const url = URL.createObjectURL(audio);
        audioElement.src = url;
        audioElement.play();
        audioElement.onended = () => URL.revokeObjectURL(url);
    }

    async fetchTtsGeneration(inputText, voiceId) {
        const response = await fetch('/api/speech/resemble/generate-voice', {
            method: 'POST',
            headers: getRequestHeaders(),
            body: JSON.stringify({
                cluster: this.settings.cluster,
                voice_uuid: voiceId,
                data: inputText,
                precision: 'PCM_16',
                apiToken: this.settings.apiToken,
            }),
        });

        if (!response.ok) {
            toastr.error(response.statusText, 'Resemble TTS Failed');
            throw new Error(`HTTP ${response.status}: ${await response.text()}`);
        }

        return response;
    }
}
