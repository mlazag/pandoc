{-
Copyright (C) 2006 John MacFarlane <jgm at berkeley dot edu>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

{- |
   Module      : Text.ParserCombinators.Pandoc 
   Copyright   : Copyright (C) 2006 John MacFarlane
   License     : GNU GPL, version 2 or above 

   Maintainer  : John MacFarlane <jgm at berkeley dot edu>
   Stability   : alpha
   Portability : portable

Special parser combinators for Pandoc readers.
-}
module Text.ParserCombinators.Pandoc ( 
                                      anyLine,
                                      many1Till,
                                      followedBy',
                                      notFollowedBy',
                                      oneOfStrings,
                                      spaceChar,
                                      skipSpaces,
                                      blankline,
                                      blanklines,
                                      escaped,
                                      enclosed,
                                      blankBlock,
                                      nullBlock,
                                      stringAnyCase,
                                      parseFromStr
                                     ) where
import Text.ParserCombinators.Parsec
import Text.Pandoc.Definition
import Text.Pandoc.Shared
import Char ( toUpper, toLower )

--- | Parse any line of text
anyLine :: GenParser Char st [Char]
anyLine = manyTill anyChar (newline <|> (do{eof; return '\n'}))

-- | Parses a character and returns 'Null' (so that the parser can move on
-- if it gets stuck).
nullBlock :: GenParser Char st Block
nullBlock = do
  anyChar 
  return Null

-- | Parses one or more blank lines; returns 'Blank'.
blankBlock :: GenParser Char st Block
blankBlock = do
  blanklines
  return Blank

-- | Parses a space or tab.
spaceChar :: CharParser st Char
spaceChar = oneOf " \t"

-- | Skips zero or more spaces or tabs.
skipSpaces :: GenParser Char st ()
skipSpaces = skipMany spaceChar

-- | Skips zero or more spaces or tabs, then reads a newline.
blankline :: GenParser Char st Char
blankline = try (do
                   skipSpaces
                   newline)

-- | Parses one or more blank lines and returns a string of newlines.
blanklines :: GenParser Char st [Char]
blanklines = try (many1 blankline)

-- | Parses backslash, then applies character parser.
escaped :: GenParser Char st Char  -- ^ Parser for character to escape
        -> GenParser Char st Inline
escaped parser = try (do
                        char '\\'
                        result <- parser
                        return (Str [result]))

-- | Parses material enclosed between start and end parsers.
enclosed :: GenParser Char st t       -- ^ start parser
	    -> GenParser Char st end  -- ^ end parser
	    -> GenParser Char st a    -- ^ content parser (to be used repeatedly)
	    -> GenParser Char st [a]
enclosed start end parser = try (do
                                   start
                                   notFollowedBy space
                                   result <- many1Till parser (try end)
                                   return result)

-- | Like @manyTill@, but reads at least one item.
many1Till :: GenParser tok st a
	     -> GenParser tok st end
	     -> GenParser tok st [a]
many1Till p end = try (do
         first <- p
         rest <- manyTill p end
         return (first:rest))

-- | A more general form of @notFollowedBy@.  This one allows any 
-- type of parser to be specified, and succeeds only if that parser fails.
-- It does not consume any input.
notFollowedBy' :: Show b => GenParser a st b -> GenParser a st ()
notFollowedBy' parser = try (do { c <- try parser; unexpected (show c) }
                           <|> return ())

-- | The inverse of @notFollowedBy'@.  Fails if parser will fail, otherwise
-- returns @()@ (but does not consume any input).
followedBy' :: (Show b) => GenParser a st b -> GenParser a st ()
followedBy' parser = do 
  isNotFollowed <- option False (do{ notFollowedBy' parser; return True})
  if isNotFollowed 
     then fail "not followed by parser" 
     else return ()

-- | Parses one of a list of strings (tried in order).  
oneOfStrings :: [String] -> GenParser Char st String
oneOfStrings listOfStrings = choice $ map (try . string) listOfStrings

-- | Parse string, case insensitive.
stringAnyCase :: [Char] -> CharParser st String
stringAnyCase [] = string ""
stringAnyCase (x:xs) = try (do
  firstChar <- choice [ char (toUpper x), char (toLower x) ]
  rest <- stringAnyCase xs
  return (firstChar:rest))

-- | Parse contents of 'str' using 'parser' and return result.
parseFromStr :: GenParser tok st a -> [tok] -> GenParser tok st a
parseFromStr parser str = try $ do
  oldInput <- getInput
  setInput str
  result <- parser
  setInput oldInput
  return result


