/*
 *  Constants.swift
 *  PreviewYaml
 *
 *  Created by Tony Smith on 12/08/2020.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */

// Combine the app's various constants into a struct
import Foundation


struct BUFFOON_CONSTANTS {

    struct ERRORS {

        struct CODES {
            static let NONE                         = 0
            static let FILE_INACCESSIBLE            = 400
            static let FILE_WONT_OPEN               = 401
            static let BAD_MD_STRING                = 402
            static let BAD_TS_STRING                = 403
        }

        struct MESSAGES {
            static let NO_ERROR                     = "No error"
            static let FILE_INACCESSIBLE            = "Can't access file"
            static let FILE_WONT_OPEN               = "Can't open file"
            static let BAD_MD_STRING                = "Can't get yaml data"
            static let BAD_TS_STRING                = "Can't access NSTextView's TextStorage"
        }
    }

    struct THUMBNAIL_SIZE {

        static let ORIGIN_X                         = 0
        static let ORIGIN_Y                         = 0
        static let WIDTH                            = 768
        static let HEIGHT                           = 1024
        static let ASPECT                           = 0.75
        static let TAG_HEIGHT                       = 204.8
        static let FONT_SIZE                        = 130.0
    }

    struct PREVIEW_SIZE {

        static let FONT_SIZE                        = 16.0
        static let INDENT                           = 2
        static let MARGIN_WIDTH                     = 16.0
        static let FONT_SIZE_OPTIONS: [CGFloat]     = [10.0, 12.0, 14.0, 16.0, 18.0, 24.0, 28.0]
        static let PREVIEW_MARGIN_WIDTH_MIN         = 0
        static let PREVIEW_MARGIN_WIDTH_MAX         = 256
        static let PREVIEW_MARGIN_SIZE              = NSSize(width: MARGIN_WIDTH, height: MARGIN_WIDTH)
    }

    //static let BASE_PREVIEW_FONT_SIZE: Float    = 16.0
    //static let BASE_THUMB_FONT_SIZE: Float      = 22.0
    //static let TAG_TEXT_SIZE                    = 180
    //static let TAG_TEXT_MIN_SIZE                = 118
    //static let CODE_COLOUR_INDEX                = 0
    //static let CODE_FONT_INDEX                  = 2     // Helvetica
    //static let YAML_INDENT                      = 2
    //static let CODE_COLOUR_HEX                  = "007D78FF"




    
    struct APP_URLS {
        
        static let PM                               = "https://apps.apple.com/us/app/previewmarkdown/id1492280469?ls=1"
        static let PC                               = "https://apps.apple.com/us/app/previewcode/id1571797683?ls=1"
        static let PY                               = "https://apps.apple.com/us/app/previewyaml/id1564574724?ls=1"
        static let PJ                               = "https://apps.apple.com/us/app/previewjson/id6443584377?ls=1"
        static let PT                               = "https://apps.apple.com/us/app/previewtext/id1660037028?ls=1"
    }
    
    struct PREFS_IDS {

        static let WHATS_NEW                        = "com-bps-previewyaml-do-show-whats-new-"
        static let PREVIEW_BODY_FONT_SIZE           = "com-bps-previewyaml-base-font-size"
        static let PREVIEW_BODY_FONT_NAME           = "com-bps-previewyaml-base-font-name"
        static let PREVIEW_USE_LIGHT                = "com-bps-previewyaml-do-use-light"
        static let PREVIEW_SHOW_MARKS               = "com-bps-previewyaml-show-key-colon"
        static let PREVIEW_SHOW_RAW                 = "com-bps-previewyaml-show-bad-yaml"
        static let PREVIEW_YAML_INDENT              = "com-bps-previewyaml-yaml-indent"
        static let PREVIEW_KEYS_COLOUR              = "com-bps-previewyaml-code-colour-hex"
        static let PREVIEW_STRINGS_COLOUR           = "com-bps-previewyaml-string-colour-hex"
        static let PREVIEW_SPECIALS_COLOUR          = "com-bps-previewyaml-special-colour-hex"
        static let PREVIEW_MARKS_COLOUR             = "com-bps-previewyaml-marks-colour-hex"
        static let PREVIEW_INDENT_SCALARS           = "com-bps-previewyaml-do-indent-scalars"
        static let PREVIEW_MARGIN_WIDTH             = "com-bps-previewyaml-preview-margin-width"
        static let PREVIEW_WINDOW_SCALE             = "com-bps-previewyaml-preview-window-scale"
        static let THUMB_MATCH_FINDER               = "com-bps-previewyaml-thumbnail-match-finder"

        //static let THUMB_SIZE                   = "com-bps-previewyaml-thumb-font-size"
        //static let TAG                          = "com-bps-previewyaml-do-show-tag"
        //static let SORT                         = "com-bps-previewyaml-sort-keys"
    }

    struct HEX_COLOUR {

        static let KEYS                             = "007D78FF"
        static let STRINGS                          = "FC6A5DFF"
        static let SPECIALS                         = "D0BF69FF"
        static let MARKS                            = "929292FF"
    }

    struct COLOUR_IDS {

        static let KEYS                             = "keys"
        static let STRINGS                          = "strings"
        static let SPECIALS                         = "specials"
        static let MARKS                            = "marks"
        static let NEW_KEYS                         = "new_keys"
        static let NEW_STRINGS                      = "new_strings"
        static let NEW_SPECIALS                     = "new_specials"
        static let NEW_MARKS                        = "new_marks"
    }

    static let COLOUR_OPTIONS                       = [BUFFOON_CONSTANTS.COLOUR_IDS.KEYS,
                                                       BUFFOON_CONSTANTS.COLOUR_IDS.STRINGS,
                                                       BUFFOON_CONSTANTS.COLOUR_IDS.SPECIALS,
                                                       BUFFOON_CONSTANTS.COLOUR_IDS.MARKS]

    struct SCALERS {

        static let WINDOW_SIZE_L                    = 0.75
        static let WINDOW_SIZE_M                    = 0.50
        static let WINDOW_SIZE_S                    = 0.42
    }

    static let MAX_FEEDBACK_SIZE                    = 512

    static let URL_MAIN                             = "https://smittytone.net/previewyaml/index.html"
    static let APP_STORE                            = "https://apps.apple.com/us/app/previewyaml/id1564574724"
    static let SUITE_NAME                           = ".suite.preview-yaml"
    static let APP_CODE_PREVIEWER                   = "com.bps.PreviewYaml.Yaml-Previewer"

    static let BODY_FONT_NAME                       = "Menlo-Regular"

    static let SAMPLE_UTI_FILE                      = "sample.yml"
    static let THUMBNAIL_LINE_COUNT                 = 30

#if DEBUG2
    static let CR                               = "↵\n"
    static let COLLECTION_SPACER                = "⟼\n"
    static let TAB                              = "↦\t"
#else
    static let CR                               = "\n"
    static let COLLECTION_SPACER                = "\n"
    static let TAB                              = "\t"
#endif
}
