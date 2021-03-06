import XMonad
import Graphics.X11.ExtraTypes.XF86
import Data.List (elemIndex)

import qualified XMonad.StackSet as W

import XMonad.Actions.FocusNth (focusNth)
import XMonad.Hooks.DynamicLog (xmobarColor, shorten, PP(..), wrap)
import XMonad.Hooks.EwmhDesktops (ewmh, fullscreenEventHook)
import XMonad.Hooks.ManageDocks (avoidStruts, docks, manageDocks)
import XMonad.Hooks.Multibar (xmobars, multiPP)
import XMonad.Hooks.DynamicLog (dynamicLogWithPP)

import XMonad.Layout.IM (withIM, Property(Role, And, ClassName))
import XMonad.Layout.PerWorkspace (onWorkspace)
import XMonad.Layout.Renamed (renamed, Rename(..))
import XMonad.Layout.SimpleDecoration (shrinkText)
import XMonad.Layout.Tabbed (tabbed, Theme(..))
import XMonad.Layout.Terminal (terminal80)

import XMonad.Util.EZConfig (removeKeys, additionalKeys)
import XMonad.Util.Run (spawnPipe)

import System.Exit (exitSuccess)
import System.IO (hPutStrLn)

main = do
  handle <- spawnPipe "xmobar 2>~/.xmonad/xmobar.err ~/.xmonad/xmobarrc.0"
  xmonad $ cbiffleConfig def handle

-- I put all desktop environment keybindings under a single modifier key,
modm = mod1Mask

-- Derives my config from a 'base'.
cbiffleConfig base hmap = ewmh $ docks $ base
  { layoutHook = avoidStruts $ onWorkspace "3" imLayout cbiffleLayout
  , manageHook = manageDocks <+> manageHook base
  , handleEventHook = handleEventHook base <+> fullscreenEventHook
  , logHook = cbiffleLogHook hmap
  , workspaces = cbiffleWorkspaces
  , terminal = "gnome-terminal"

  , modMask = modm
  , normalBorderColor = "#0000dd"   -- slightly subdued blue for inactive
  , focusedBorderColor = "#ff0000"  -- bright red for active
  , focusFollowsMouse = False       -- only change focus explicitly
  , clickJustFocuses = False        -- pass first click through to app
  } `removeKeys` cbiffleUnwantedKeys
    `additionalKeys` cbiffleKeys

-- My workspaces are numerically numbered starting at 1; I have 12 of them
-- to correspond with my function keys.
cbiffleWorkspaces = [show i | i <- [1..12 :: Integer]]

workspaceNumber = flip elemIndex cbiffleWorkspaces

-- Distributes log events across multiple XMobar instances (see
-- XMonad.Hooks.Multibar in this same repo).
cbiffleLogHook handle = dynamicLogWithPP (pp "yellow" "green" ("red", "yellow"))
  where
    pp currentC titleC (urgentFC, urgentBC) = def
      { ppCurrent = clickableWS (xmobarColor currentC "" . wrap "[" "]" . cook)
          -- Current is square-bracketed.
      , ppVisible = clickableWS (wrap "(" ")" . cook)
          -- Visible but non-focused workspace, round-bracketed.
      , ppHidden = clickableWS (wrap " " " " . cook)
          -- Populated but invisible workspace, not bracketed.
          -- Unpopulated workspaces are garbage-collected.
      , ppUrgent = xmobarColor urgentFC urgentBC
          -- Highlight indicator if window signals urgency.
      , ppTitle = xmobarColor titleC "" . cook . shorten 150
          -- Truncate and escape titles.
      , ppWsSep = ""
          -- Don't bother separating workspace indicators.
      , ppOutput = hPutStrLn handle
      }

-- Make workspace indicators clickable when wmctrl is available.
clickableWS f ws = case workspaceNumber ws of
    Nothing -> f ws
    Just n -> "<action=`wmctrl -s " ++ show n ++ "`>" ++ f ws ++ "</action>"
-- Prepare an arbitrary raw string for presentation using XMobar's unsafe
-- stdin formatter.  This escapes any embedded sequences that XMobar might
-- otherwise interpret.
cook s = "<raw=" ++ show (length s) ++ ":" ++ s ++ "/>"

tabbedLayout = tabbed shrinkText tabbedConf

tabbedConf = def {
    fontName = "xft:Droid Sans Mono:size=9:bold:antialias=true"
    {-fontName = "-*-consolas-*-*-*-*-24-*-*-*-*-*-*-*"-}
    {-, decoHeight = 24-}
}


-- I allow each workspace to switch between three layouts.
cbiffleLayout =
  -- My font-sensitive terminal pane layout (default),
  renamed [CutWordsLeft 1, PrependWords (icon "layout-terminal")] terminal80
  -- A tabbed fullscreen layout that I find useful for web and graphics work.
  ||| rename (icon "layout-tabbed") tabbedLayout
  -- XMonad's classic Tall layout, with some tweaks.
  ||| rename (icon "layout-tall") (Tall 1 (3/100) (1/2))
  where
    -- I use icons in place of the text layout names to indicate status.  This
    -- is shorthand for discarding a layout's name and replacing it.
    rename s = renamed [Replace s]
    icon relpath = "<icon=/usr/local/google/home/chuklin/.xmonad/img/" ++ relpath ++ ".xbm/>"

-- Special layout for the workspace where I do IM.
imLayout = withIM (1/4)
                  (And (ClassName "Pidgin") (Role "buddy_list"))
                  cbiffleLayout

cbiffleUnwantedKeys =
  -- My workspaces are on the F-keys, not the numerals.  Unmap the mod-numeral
  -- keys.  We'll remap them shortly.
  [(modm .|. shiftMask, n) | n <- [xK_1 .. xK_9]] ++
  [(modm, n) | n <- [xK_1 .. xK_9]] ++
  [ (modm, xK_p)
  , (modm .|. shiftMask, xK_p)
  , (modm, xK_m)
  , (modm, xK_Return)
  , (modm .|. shiftMask, xK_q)
  ] ++
  [(modm, xK_space), (modm .|. shiftMask, xK_space)]

cbiffleKeys = actionKeys ++ workspaceKeys ++ windowKeys ++ layoutKeys
  where
    actionKeys =
      [ ((mod4Mask,                 xK_space), spawn "dmenu_run -p Run:")
          -- Minimal run dialog from dmenu
      , ((modm .|. shiftMask,   xK_q), restart "xmonad" False)
          -- Modm-Q restarts xmonad, preserving state.
          -- Extend this with Modm-SHIFT-Q which discards state.
          -- This effectively reboots the window manager.
      , ((modm .|. controlMask, xK_q), io exitSuccess)
          -- And Modm-CTRL-Q kills XMonad, logging out.
      , ((modm .|. controlMask, xK_l), spawn "light-locker-command -l")
          -- Modm-CTRL-L locks the screen when light-locker is running.

      -- Useful bindings for modern multimedia keyboards:
      , ((0, xK_Print), spawn "scrot")  -- Print Screen takes a screenshot
      , ((0, xF86XK_AudioRaiseVolume), raiseVolume)   -- \
      , ((0, xF86XK_AudioLowerVolume), lowerVolume)   -- | audio
      , ((0, xF86XK_AudioMute),        muteAudio)     -- | keys
      , ((0, xF86XK_AudioMicMute),     muteMic)       -- /
      , ((0, xF86XK_MonBrightnessUp),   raiseBrightness) -- backlight
      , ((0, xF86XK_MonBrightnessDown), lowerBrightness) -- control
      -- Copied from http://google3/googledata/corp/puppet/goobuntu/common/modules/dconf/manifests/init.pp?l=86&rcl=185809524.
      -- F13 gear/flower icon
      , ((0, xF86XK_Tools), spawn "env XSECURELOCK_PAM_SERVICE=xsecurelock XSECURELOCK_WANT_FIRST_KEYPRESS=1 xsecurelock")
      ]

    workspaceKeys = [ ((modm .|. m, k), windows $ f i)
                    | (i, k) <- zip cbiffleWorkspaces [xK_F1..]
                    , (m, f) <- [ (0, W.view)
                                  -- Modm-Fx switches to workspace x.  If it is
                                  -- already on a display, focus moves to that
                                  -- display.  Otherwise, it replaces the
                                  -- current workspace on the focused display.
                                , (controlMask, W.greedyView)
                                  -- Modm-CTRL-Fx switches to workspace x on
                                  -- the current display.  If it is visible
                                  -- elsewhere, the displays are swapped.
                                , (shiftMask, W.shift)
                                  -- Modm-SHIFT-Fx moves the currently focused
                                  -- window onto workspace x.
                                ]
                    ]

    -- Modm-n focuses window n on the current workspace.
    windowKeys = [((modm, k), focusNth w) | (k, w) <- zip [xK_1..xK_9] [0..]]

    layoutKeys = [((modm .|. shiftMask, xK_space), sendMessage NextLayout)]


-------------------------------------------------------------------------------
-- Utilities for interacting with the system

setVolume s = spawn $ "amixer set Master " ++ s ++ " unmute"
raiseVolume = setVolume "5%+"
lowerVolume = setVolume "5%-"
muteAudio = spawn "amixer set Master toggle"
muteMic = spawn "amixer set Capture toggle"

raiseBrightness = spawn "xbacklight +10"
lowerBrightness = spawn "xbacklight -10"
