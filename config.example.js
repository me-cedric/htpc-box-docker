"use strict";

// Copy this file to config.js. Replace all placeholder values before startup.
// Keep config.js private. It contains API keys and torrent-client credentials.
module.exports = {
    apiKey: undefined,

    torznab: [
        "http://prowlarr:9696/INDEXER_ID/api?apikey=YOUR_PROWLARR_API_KEY",
    ],
    sonarr: ["http://sonarr:8989/?apikey=YOUR_SONARR_API_KEY"],
    radarr: ["http://radarr:7878/?apikey=YOUR_RADARR_API_KEY"],

    host: "0.0.0.0",
    port: 2468,
    notificationWebhookUrls: [],

    // URL-encode the username and password before you add them to this URL.
    torrentClients: [
        "qbittorrent:http://YOUR_URL_ENCODED_USERNAME:YOUR_URL_ENCODED_PASSWORD@gluetun:8123",
    ],

    useClientTorrents: true,
    delay: 30,
    dataDirs: [],
    linkCategory: "cross-seed-link",
    linkDirs: ["/downloads/cross-seed-links"],
    linkType: "hardlink",
    flatLinking: false,
    matchMode: "partial",
    skipRecheck: true,
    autoResumeMaxDownload: 52428800,
    ignoreNonRelevantFilesToResume: false,
    maxDataDepth: 2,
    torrentDir: null,
    outputDir: null,
    includeSingleEpisodes: true,
    includeNonVideos: true,
    seasonFromEpisodes: 1,
    fuzzySizeThreshold: 0.02,
    excludeOlder: "2 weeks",
    excludeNewer: "1 hour",
    excludeRecentSearch: "3 days",
    action: "inject",
    duplicateCategories: false,
    rssCadence: "30 minutes",
    searchCadence: "1 day",
    snatchTimeout: "30 seconds",
    searchTimeout: "2 minutes",
    searchLimit: 400,
    blockList: [],
};
