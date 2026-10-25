# TVer API findings (verified live from JP, 2026-10-25)

Session: POST platform-api.tver.jp/v2/api/platform_users/browser/create (device_type=pc)
-> platform_uid / platform_token, sent as query params. Header x-tver-platform-type: web.

## Search (implemented)
- SDK (s.tver.jp/appsdk.js) `TVerApp.callKeywordSearchV2(keyword, {filterKey, sortKey})`
- Because params contain require_data, apiRequest routes to the platform host:
  GET https://platform-api.tver.jp/service/api/v2/callKeywordSearch
  params: keyword, require_data=later, platform_uid, platform_token (+ optional sortKey/filterKey)
- v1 variant: /service/api/v1/callKeywordSearch (same params).
- Response: code 0, result { contents[], resultCount, keyword, sortKey=_score, filterKey }
  Items: { type: episode|live|..., content: {...same fields as ranking items...}, score }
  Episodes dominate; talent-name queries return that talent's episodes. Result can be ~1000.

## Live / simulcast (next to implement)
- GET https://service-api.tver.jp/api/v1/callLiveChannel (session query OK)
  result { contents[5], defaultChannelID, specialLiveStatus }
  Channels: ntv/ex/tbs/tx/cx (name = broadcaster).
  Item: { type: "channel", content: {id, version, name},
          video: { apiKey: "ntv", projectID: "tver-simul-ntv", mediaID: "ref:simul-ntv" } }
  => Playback is the usual Streaks flow with projectID/mediaID from `video`.
     Still to verify: which key in streaks_info_v2.json applies for tver-simul-* projects
     (project api_key map may use the channel apiKey name instead of key0{month}).
- Other live endpoints (SDK): callLiveTimeline/{channelId} (v1, service host),
  callLiveEpisode/{id}?require_data=mylist (platform host /service),
  callSpecialLiveTimeline, callTopicsLiveEpisode/{id}, callRecommendLiveEpisode/{id}.

## CRITICAL: SSAI session activation for live streams
Live/simul sources carry an `ssai` block; their manifest URL (ssai-manifest.streaks.jp)
returns 403 {"errorId":"E022"} until a session is registered (same flow as yt-dlp):
  POST https://ssai.api.streaks.jp/v1/projects/{projectId}/medias/{playback.id}/ssai/session
  headers: Content-Type/Accept: application/json   body: {"id": source.id}
  -> JSON list; [0].query = "session=<uuid>" — merge those params into the src URL.
After merging, the master playlist loads (200) with variant + ARIB subtitle playlists.
Live EPISODE statics (statics.tver.jp/content/live/{id}.json?v=): liveVideo = the
channel simul ref itself; dvrVideo = {projectID: same simul project, mediaID: ref:{id}}
for DVR catch-up within the dvr window in the statics json.

## SDK routing rule (appsdk.js apiRequest)
- path builders: P() = /api/v1/..., x() = /api/v2/...
- GET without require_data and not usePlatform -> serviceAPIEndpoint + path (no /service prefix)
- POST or require_data present or usePlatform -> platformAPIEndpoint + "/service" + path
  (member host instead when logged in with member_sid)
- Always appends app_ver param; success when response JSON code === 0; payload = result.
