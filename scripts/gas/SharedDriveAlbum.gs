/**
 * 共用雲端硬碟相簿 — Google Apps Script
 *
 * 讀取共用雲端硬碟指定根資料夾下的子資料夾（相簿）與相片，
 * 回傳 JSON 供網站顯示相簿列表與相片（縮圖 + 原圖連結）。
 * 相片不複製、不搬移，僅回傳 Google 產生的 thumbnailLink / webContentLink。
 *
 * 作法與「getFolderList / getPhotosInFolder」相同：DriveApp 列資料夾與檔案；
 * 縮圖／大圖改為使用「網址」（drive.google.com/thumbnail、uc?export=view），
 * 因 DriveApp 的 file.getThumbnail() 回傳的是 Blob 而非 URL，無法直接給網頁 <img src> 使用。
 * 另：共用硬碟內列檔案時會自動改用 Drive API，否則 DriveApp 常列不到。
 *
 * 部署：部署為「網頁應用程式」，執行身份「我」，存取權「任何人」。
 * 設定：指令碼屬性 ROOT_FOLDER_ID = 相簿根目錄的資料夾 ID。
 *   - 建議：使用「共用雲端硬碟內」的某個資料夾 ID（在該資料夾上右鍵 → 取得連結），不要用共用硬碟「根」的 ID。
 *   - 若為共用硬碟根目錄 ID，會自動改用 Drive API 列出一層子資料夾（需啟用 Drive API）。
 * 進階服務：請啟用「Drive API」（擴充功能 → Google 服務）。
 */

var ROOT_FOLDER_ID_KEY = 'ROOT_FOLDER_ID';

/**
 * 網頁應用程式 GET 進入點
 * 參數：action=folders | photos；folder_id（當 action=photos 時必填）
 */
function doGet(e) {
  var params = e && e.parameter ? e.parameter : {};
  var action = (params.action || '').toLowerCase();
  var folderId = params.folder_id || '';

  var output = {};
  try {
    if (action === 'folders') {
      output = folderId ? listFoldersInFolder(folderId) : listFolders();
    } else if (action === 'photos' && folderId) {
      output = listPhotosInFolder(folderId);
    } else {
      output = { error: '請提供 action=folders 或 action=photos&folder_id=xxx' };
    }
  } catch (err) {
    output = { error: err.toString() };
  }

  return ContentService
    .createTextOutput(JSON.stringify(output))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * 【驗證用】在指令碼編輯器執行此函式，檢查 ROOT_FOLDER_ID 與根目錄子資料夾。
 * 執行後：上方選單「檢視」→「執行紀錄」或「紀錄」查看輸出。
 */
function testRootAndFolders() {
  var rootId = PropertiesService.getScriptProperties().getProperty(ROOT_FOLDER_ID_KEY);
  Logger.log('ROOT_FOLDER_ID（指令碼屬性）= ' + (rootId || '(未設定)'));
  if (!rootId) return;
  try {
    var out = listFolders();
    Logger.log('listFolders() 回傳: ' + JSON.stringify(out, null, 2));
    if (out.folders && out.folders.length > 0) {
      Logger.log('--- 第一層資料夾共 ' + out.folders.length + ' 個，名稱如下 ---');
      out.folders.forEach(function (f, i) {
        Logger.log((i + 1) + '. ' + f.name + ' (id=' + f.id + ', photo_count=' + f.photo_count + ')');
      });
    }
  } catch (e) {
    Logger.log('錯誤: ' + e.toString());
  }
}

/**
 * 列出根目錄下的子資料夾（相簿）
 * 先嘗試 DriveApp；若失敗（例如共用硬碟根），改用 Drive API 列出一層子資料夾。
 */
function listFolders() {
  var rootId = PropertiesService.getScriptProperties().getProperty(ROOT_FOLDER_ID_KEY);
  if (!rootId) {
    return { error: '請在指令碼屬性設定 ROOT_FOLDER_ID' };
  }

  try {
    var root = DriveApp.getFolderById(rootId);
    var folders = [];
    var iter = root.getFolders();
    while (iter.hasNext()) {
      var folder = iter.next();
      var count = countImageFilesInFolder(folder);
      folders.push({
        id: folder.getId(),
        name: folder.getName(),
        photo_count: count
      });
    }
    folders.sort(function (a, b) { return (a.name || '').localeCompare(b.name || '', 'zh'); });
    return { folders: folders };
  } catch (e) {
    // 共用雲端硬碟根目錄可能無法用 getFolderById，改試 Drive API 列出一層子資料夾
    return listFoldersViaDriveApi(rootId);
  }
}

/**
 * 列出「指定資料夾」內的子資料夾（用於年度底下的相簿清單）
 * 先試 DriveApp，失敗則用 Drive API。
 */
function listFoldersInFolder(parentId) {
  try {
    var root = DriveApp.getFolderById(parentId);
    var folderName = root.getName();
    var folders = [];
    var iter = root.getFolders();
    while (iter.hasNext()) {
      var folder = iter.next();
      var count = countImageFilesInFolder(folder);
      folders.push({
        id: folder.getId(),
        name: folder.getName(),
        photo_count: count
      });
    }
    folders.sort(function (a, b) { return (a.name || '').localeCompare(b.name || '', 'zh'); });
    return { folder_name: folderName, folders: folders };
  } catch (e) {
    return listFoldersViaDriveApi(parentId);
  }
}

/**
 * 用 Drive API 列出指定 ID 下的子資料夾（支援共用硬碟根）
 */
function listFoldersViaDriveApi(parentId) {
  var folders = [];
  var pageToken = null;
  do {
    var opt = {
      q: "'" + parentId + "' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      fields: 'nextPageToken, items(id, title)',
      maxResults: 100,
      supportsAllDrives: true,
      includeItemsFromAllDrives: true
    };
    if (pageToken) opt.pageToken = pageToken;
    var result = Drive.Files.list(opt);
    if (result.items) {
      for (var i = 0; i < result.items.length; i++) {
        var item = result.items[i];
        var count = countImageFilesInFolderViaDriveApi(item.id);
        folders.push({
          id: item.id,
          name: item.title || item.id,
          photo_count: count
        });
      }
    }
    pageToken = result.nextPageToken || null;
  } while (pageToken);

  folders.sort(function (a, b) { return (a.name || '').localeCompare(b.name || '', 'zh'); });
  var folderName = '';
  try {
    var parentFile = Drive.Files.get(parentId, { fields: 'title', supportsAllDrives: true });
    folderName = parentFile.title || '';
  } catch (e) {}
  return { folder_name: folderName, folders: folders };
}

/**
 * 用 Drive API 計算資料夾內圖片數量（不遞迴）
 */
function countImageFilesInFolderViaDriveApi(folderId) {
  var count = 0;
  var pageToken = null;
  do {
    var opt = {
      q: "'" + folderId + "' in parents and trashed = false and (mimeType = 'image/jpeg' or mimeType = 'image/png' or mimeType = 'image/gif' or mimeType = 'image/webp' or mimeType = 'image/bmp')",
      fields: 'nextPageToken, items(id)',
      maxResults: 500,
      supportsAllDrives: true,
      includeItemsFromAllDrives: true
    };
    if (pageToken) opt.pageToken = pageToken;
    var result = Drive.Files.list(opt);
    if (result.items) count += result.items.length;
    pageToken = result.nextPageToken || null;
  } while (pageToken);
  return count;
}

/**
 * 計算資料夾內圖片檔數量（不遞迴）
 */
function countImageFilesInFolder(folder) {
  var count = 0;
  var iter = folder.getFiles();
  while (iter.hasNext()) {
    var file = iter.next();
    if (isImageMimeType(file.getMimeType())) count++;
  }
  return count;
}

/**
 * 列出指定資料夾內的相片（回傳 thumbnailLink、webContentLink）
 * 先試 DriveApp；若無相片或失敗則改用 Drive API（共用硬碟需用 API 才列得到檔案）
 */
function listPhotosInFolder(folderId) {
  var folderName = '';
  var photos = [];
  try {
    var folder = DriveApp.getFolderById(folderId);
    folderName = folder.getName();
    var iter = folder.getFiles();
    while (iter.hasNext()) {
      var file = iter.next();
      if (!isImageMimeType(file.getMimeType())) continue;
      var id = file.getId();
      var meta = getFileLinks(id);
      var thumb = meta.thumbnailLink || '';
      var web = meta.webContentLink || '';
      if (!thumb) thumb = 'https://drive.google.com/thumbnail?id=' + id + '&sz=w400';
      if (!web) web = 'https://drive.google.com/uc?id=' + id + '&export=view';
      photos.push({ id: id, name: file.getName(), thumbnail_link: thumb, web_content_link: web });
    }
  } catch (e) {}
  if (photos.length === 0) {
    return listPhotosInFolderViaDriveApi(folderId);
  }
  return { folder_name: folderName, photos: photos };
}

/**
 * 用 Drive API 列出資料夾內相片（支援共用硬碟）
 */
function listPhotosInFolderViaDriveApi(folderId) {
  var folderName = '';
  try {
    var folderMeta = Drive.Files.get(folderId, { fields: 'title', supportsAllDrives: true });
    folderName = folderMeta.title || '';
  } catch (e) {}
  var photos = [];
  var pageToken = null;
  var imageMimeTypes = ["image/jpeg", "image/png", "image/gif", "image/webp", "image/bmp", "image/heic"];
  var mimeQuery = imageMimeTypes.map(function(m) { return "mimeType = '" + m + "'"; }).join(" or ");
  do {
    var opt = {
      q: "'" + folderId + "' in parents and trashed = false and (" + mimeQuery + ")",
      fields: 'nextPageToken, items(id, title)',
      maxResults: 100,
      supportsAllDrives: true,
      includeItemsFromAllDrives: true
    };
    if (pageToken) opt.pageToken = pageToken;
    var result = Drive.Files.list(opt);
    if (result.items) {
      for (var i = 0; i < result.items.length; i++) {
        var item = result.items[i];
        var id = item.id;
        var meta = getFileLinks(id);
        var thumb = meta.thumbnailLink || '';
        var web = meta.webContentLink || '';
        if (!thumb) thumb = 'https://drive.google.com/thumbnail?id=' + id + '&sz=w400';
        if (!web) web = 'https://drive.google.com/uc?id=' + id + '&export=view';
        photos.push({
          id: id,
          name: item.title || id,
          thumbnail_link: thumb,
          web_content_link: web
        });
      }
    }
    pageToken = result.nextPageToken || null;
  } while (pageToken);
  return { folder_name: folderName, photos: photos };
}

function isImageMimeType(mimeType) {
  return mimeType && mimeType.indexOf('image/') === 0;
}

// ---- 與「getFolderList / getPhotosInFolder」相同邏輯的對外介面（供 HtmlService 或手動呼叫）----
// 若要用固定 FOLDER_ID，可在程式開頭加：const FOLDER_ID = '您的資料夾ID';

/** 取得根目錄下所有年度／社別資料夾清單（依名稱排序，2025-26 在前） */
function getFolderList() {
  var rootId = PropertiesService.getScriptProperties().getProperty(ROOT_FOLDER_ID_KEY);
  if (!rootId) return [];
  var out = listFolders();
  if (out.error || !out.folders) return [];
  return out.folders.map(function (f) { return { id: f.id, name: f.name }; });
}

/** 取得指定資料夾內的相片（縮圖與大圖皆為 URL，支援 JPEG/PNG/GIF 等；共用硬碟會自動用 Drive API） */
function getPhotosInFolder(folderId) {
  if (!folderId) return [];
  var out = listPhotosInFolder(folderId);
  if (out.error || !out.photos) return [];
  return out.photos.map(function (p) {
    return {
      name: p.name,
      thumb: p.thumbnail_link || ('https://drive.google.com/thumbnail?id=' + p.id + '&sz=w400'),
      url: p.web_content_link || ('https://drive.google.com/uc?export=view&id=' + p.id)
    };
  });
}

/**
 * 透過 Drive API 取得檔案的縮圖與下載連結（支援共用硬碟）
 */
function getFileLinks(fileId) {
  try {
    var file = Drive.Files.get(fileId, {
      fields: 'thumbnailLink,webContentLink',
      supportsAllDrives: true
    });
    return {
      thumbnailLink: file.thumbnailLink || null,
      webContentLink: file.webContentLink || null
    };
  } catch (e) {
    return { thumbnailLink: null, webContentLink: null };
  }
}
