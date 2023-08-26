/*
 *  Constants.swift
 *  PreviewYaml
 *
 *  Created by Tony Smith on 12/08/2020.
 *  Copyright © 2023 Tony Smith. All rights reserved.
 */

// Combine the app's various constants into a struct
import Foundation


struct BUFFOON_CONSTANTS {

    struct ERRORS {

        struct CODES {
            static let NONE                     = 0
            static let FILE_INACCESSIBLE        = 400
            static let FILE_WONT_OPEN           = 401
            static let BAD_MD_STRING            = 402
            static let BAD_TS_STRING            = 403
        }

        struct MESSAGES {
            static let NO_ERROR                 = "No error"
            static let FILE_INACCESSIBLE        = "Can't access file"
            static let FILE_WONT_OPEN           = "Can't open file"
            static let BAD_MD_STRING            = "Can't get yaml data"
            static let BAD_TS_STRING            = "Can't access NSTextView's TextStorage"
        }
    }

    struct THUMBNAIL_SIZE {

        static let ORIGIN_X                     = 0
        static let ORIGIN_Y                     = 0
        static let WIDTH                        = 768
        static let HEIGHT                       = 1024
        static let ASPECT                       = 0.75
        static let TAG_HEIGHT                   = 204.8
        static let FONT_SIZE                    = 130.0
    }

    static let BASE_PREVIEW_FONT_SIZE: Float    = 16.0
    static let BASE_THUMB_FONT_SIZE: Float      = 22.0

    static let CODE_COLOUR_INDEX                = 0
    static let CODE_FONT_INDEX                  = 2     // Helvetica

    static let FONT_SIZE_OPTIONS: [CGFloat]     = [10.0, 12.0, 14.0, 16.0, 18.0, 24.0, 28.0]

    static let YAML_INDENT                      = 2

    // FROM 1.0.1
    static let URL_MAIN                         = "https://smittytone.net/previewyaml/index.html"
    static let APP_STORE                        = "https://apps.apple.com/us/app/previewyaml/id1564574724"
    static let SUITE_NAME                       = ".suite.preview-yaml"

    static let TAG_TEXT_SIZE                    = 180
    static let TAG_TEXT_MIN_SIZE                = 118
    
    // FROM 1.1.0
    static let CODE_FONT_NAME                   = "Menlo-Regular"
    static let CODE_COLOUR_HEX                  = "007D78FF"
    
    static let SAMPLE_UTI_FILE                  = "sample.yml"

    // FROM 1.1.1
    static let THUMBNAIL_LINE_COUNT             = 30
    
    // FROM 1.1.2
    static let APP_CODE_PREVIEWER               = "com.bps.PreviewYaml.Yaml-Previewer"
    
    // FROM 1.1.4
    struct APP_URLS {
        
        static let PM                           = "https://apps.apple.com/us/app/previewmarkdown/id1492280469?ls=1"
        static let PC                           = "https://apps.apple.com/us/app/previewcode/id1571797683?ls=1"
        static let PY                           = "https://apps.apple.com/us/app/previewyaml/id1564574724?ls=1"
        static let PJ                           = "https://apps.apple.com/us/app/previewjson/id6443584377?ls=1"
        static let PT                           = "https://apps.apple.com/us/app/previewtext/id1660037028?ls=1"
    }
    
    static let WHATS_NEW_PREF                   = "com-bps-previewyaml-do-show-whats-new-"

    // FROM 1.2.0
    struct PREFS_KEYS {

        static let BODY_SIZE                    = "com-bps-previewyaml-base-font-size"
        static let THUMB_SIZE                   = "com-bps-previewyaml-thumb-font-size"
        static let CODE_COLOUR                  = "com-bps-previewyaml-code-colour-hex"
        static let CODE_FONT                    = "com-bps-previewyaml-base-font-name"
        static let USE_LIGHT                    = "com-bps-previewyaml-do-use-light"
        static let TAG                          = "com-bps-previewyaml-do-show-tag"
        static let WHATS_NEW                    = "com-bps-previewyaml-do-show-whats-new-"
        static let INDENT                       = "com-bps-previewyaml-yaml-indent"
        static let SCALARS                      = "com-bps-previewyaml-do-indent-scalars"
        static let BAD                          = "com-bps-previewyaml-show-bad-yaml"
        static let SORT                         = "com-bps-previewyaml-sort-keys"
        static let COLON                        = "com-bps-previewyaml-show-key-colon"
        static let STRING_COLOUR                = "com-bps-previewyaml-string-colour-hex"
        static let SPECIAL_COLOUR               = "com-bps-previewyaml-special-colour-hex"
    }

    static let STRING_COLOUR_HEX                = "FC6A5DFF"
    static let SPECIAL_COLOUR_HEX               = "D0BF69FF"
}
