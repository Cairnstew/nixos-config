import fetch from 'node-fetch';
import { forwardFetchResponse } from '../util.js';

export const resemble = express.Router();

resemble.post('/generate-voice', async (req, res) => {
    try {
        const { cluster, voice_uuid, data, precision, apiToken } = req.body;

        if (!cluster || !voice_uuid || !data) {
            console.warn('Resemble TTS request missing required parameters');
            return res.sendStatus(400);
        }

        const endpoint = `https://${cluster}.cluster.resemble.ai/stream`;

        const response = await fetch(endpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                ...(apiToken ? { 'Authorization': `Bearer ${apiToken}` } : {}),
            },
            body: JSON.stringify({
                voice_uuid: voice_uuid,
                data: data,
                precision: precision || 'PCM_16',
            }),
        });

        if (!response.ok) {
            const text = await response.text();
            console.warn(`Resemble TTS failed: HTTP ${response.status} - ${text}`);
            return res.sendStatus(500);
        }

        res.set('Content-Type', 'audio/wav');
        await forwardFetchResponse(response, res);
    } catch (error) {
        console.error('Resemble TTS error', error);
        return res.sendStatus(500);
    }
});
