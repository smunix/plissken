{-# LANGUAGE NamedFieldPuns, StandaloneDeriving, LambdaCase, OverloadedStrings #-}
{-# OPTIONS_GHC -funbox-strict-fields #-}
module Controls where
import qualified Data.Map.Strict     as M
import qualified Data.Foldable       as F
import qualified Graphics.UI.GLFW as GLFW
import Graphics.UI.GLFW (Key(..))

import Control.Lens
import Control.Concurrent
import Control.Monad.Writer.Strict
import Control.Applicative
import Data.IORef

import Data.Int
import qualified Data.Text as T
import Data.Text (Text)
import Data.Maybe (fromMaybe)
import Data.Monoid

import Text.Read (readMaybe)

import Save

data Event
    = ToggleMenu
    | Select
    | Back
    | MenuUp
    | MenuDown

    | AbsX !Int8
    | AbsY !Int8
    | AbsZ !Int8
    | Flamethrow
    | EndGame

    | Delete
    | Delete4x4
  deriving (Show,Read,Eq,Ord)

type Scheme = M.Map GLFW.Key Event

defaultScheme :: Scheme
defaultScheme = execWriter $ do
    -- movement controls
    CharKey 'S'  `maps` AbsY (-1)
    CharKey 'W'  `maps` AbsY 1
    CharKey 'A'  `maps` AbsX (-1)
    CharKey 'D'  `maps` AbsX 1
    CharKey 'E'  `maps` AbsZ (-1)
    CharKey 'Q'  `maps` AbsZ 1
    CharKey 'K'  `maps` EndGame
    CharKey ' '  `maps` Flamethrow
    KeySpace     `maps` Flamethrow
    KeyBackspace `maps` Delete
    CharKey 'O'  `maps` Delete4x4
    -- menu controls
    KeyEsc       `maps` ToggleMenu
    KeyEnter     `maps` Select
    KeyUp        `maps` MenuUp
    KeyDown      `maps` MenuDown
    KeyRight     `maps` Select
    KeyLeft      `maps` Back
  where
    maps k x    = tell (M.singleton k x)

{-# INLINE withControls #-}
withControls :: Scheme -> GLFW.Key -> (GLFW.Key -> IO ()) -> (Event -> IO ()) -> IO ()
withControls s k fallback cc = case M.lookup k s of
    Just ev -> fallback k >> cc ev
    _       -> fallback k

buildScheme :: Config -> Scheme
buildScheme 
    = flip M.union defaultScheme
    . M.map valToEvent
    . M.mapKeys (\ck -> errorWhenInvalidKey ck (saveKeyToGLFW ck)) 
    . M.filterWithKey (\k _ -> isControl k)
  where
    isControl :: Save.Key -> Bool
    isControl (Key ["controls",_] TT) = True
    isControl _                       = False
    
    readGLFWkey :: Text -> Maybe GLFW.Key
    readGLFWkey = readMaybe . T.unpack . T.map (\case '_' -> ' '; a -> a)
    
    errorWhenInvalidKey :: Save.Key -> Maybe GLFW.Key -> GLFW.Key
    errorWhenInvalidKey s Nothing  = error $ "Invalid control "     ++ show s ++ "."
    errorWhenInvalidKey _ (Just k) = k

    valToEvent :: Value -> Event
    valToEvent (T v)
        = fromMaybe
            (error ("Invalid event " ++ show v))
            (readMaybe (T.unpack v))

    valToEvent s     = error $ "Expected a string, got " ++ show s

    saveKeyToGLFW :: Save.Key -> Maybe GLFW.Key
    saveKeyToGLFW (Key ["controls",x] _) = readGLFWkey x
    saveKeyToGLFW _                      = Nothing
