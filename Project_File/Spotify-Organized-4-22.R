################################################################################
## Libraries -----

#install.packages("devtools")
#library(devtools)
#devtools::install_github("")
#install.packages('genius')
#install.packages("lexicon")
library(spotifyr)
library(genius)
library(tm)
library(wordcloud)
library(tidyr)
library(lexicon)
library(tidytext)
library(plyr)


################################################################################
# Spotify authorizations -----

# Authorize Spotify API info
Sys.setenv(SPOTIFY_CLIENT_ID = '3d49f13ca5124a8280e741a3f3842ff7')
Sys.setenv(SPOTIFY_CLIENT_SECRET = '6aaabaa303b548ee97f1b286a68933c9')
access_token <- get_spotify_access_token()


################################################################################
# Getting playlists -----

# Get playlist categories
cats <- get_categories()


# Hiphop category
hiphop <- get_category_playlists("hiphop")

RapCaviar <- get_playlist("37i9dQZF1DX0XUsuxWHRQd")
MostNecessary <- get_playlist("37i9dQZF1DX2RxBh64BHjQ")
SignedXOXO <- get_playlist("37i9dQZF1DX2A29LI7xHn1")


# Pop category
pop <- get_category_playlists("pop")

TodaysTopHits <- get_playlist("37i9dQZF1DXcBWIGoYBM5M")
PopRising <- get_playlist("37i9dQZF1DWUa8ZRTfalHk")


# Rock category
rock <- get_category_playlists("rock")

RockThis <- get_playlist("37i9dQZF1DXcF6B6QPhFDv")
AltNOW <- get_playlist("37i9dQZF1DWVqJMsgEN0F4")
RockHard <- get_playlist("37i9dQZF1DWWJOmJ7nRx0C")


# Metal category
metal <- get_category_playlists("metal")

KickassMetal <- get_playlist("37i9dQZF1DWTcqUzwhNmKv")
NewCore <- get_playlist("37i9dQZF1DWXIcbzpLauPS")
NuMetalGeneration <- get_playlist("37i9dQZF1DXcfZ6moR6J0G")


# Indie category
indie <- get_category_playlists("indie_alt")

Alternative10s <- get_playlist("37i9dQZF1DX873GaRGUmPl")
EarlyAlternative <- get_playlist("37i9dQZF1DXdTCdwCKzXwo")
Alternative00s <- get_playlist("37i9dQZF1DX0YKekzl0blG")



################################################################################
## Efrain's playlist to df function -----

playlist_to_df <- function(playlist){
  
  #creates df of Track Names and Pop Score
  outputDF <- data.frame(playlist[["tracks"]][["items"]][["track.name"]],playlist[["tracks"]][["items"]][["track.popularity"]])
  colnames(outputDF)<-c("name","popularity")
  outputDF$name <-gsub("\\s*\\([^\\)]+\\)","",as.character(outputDF$name))
  #removes all parenthesis and everything inside them
  
  #artist name added to df
  vector1 <- character(nrow(outputDF))
  for(i in 1:nrow(outputDF)){
    vector1[i]<- playlist[["tracks"]][["items"]][["track.artists"]][[i]][["name"]][[1]]
  }
  outputDF$artist <- vector1
  
  #lyric time
  outputDF$lyrics <-NA
  
  #error handling to keep on adding to df if lyrics cannot be found
  for(i in 1:nrow(outputDF)){
    try({
      lyrics_from_genius <- genius_lyrics(artist = outputDF$artist[i],song = outputDF$name[i], info = "simple")
      lyric_list <- lyrics_from_genius$lyric
      outputDF$lyrics[i] <- paste(unlist(lyric_list),collapse=' ')
      
    })
    
    
    #Adds additional track audio features to our data frame. key, energy, loudness, mode etc...
    playID <- playlist[["id"]]
    features_df <- get_playlist_audio_features("spotify",playID)
    
    try({
    outputDF$danceability <- NA
    outputDF$danceability <- features_df$danceability
    outputDF$key <- features_df$key
    outputDF$energy <- features_df$energy
    outputDF$loudness <- features_df$loudness
    outputDF$mode <- features_df$mode
    outputDF$speechiness <- features_df$speechiness
    outputDF$acousticness <- features_df$acousticness
    outputDF$instrumentalness <- features_df$instrumentalness
    outputDF$liveness <- features_df$liveness
    outputDF$valence <- features_df$valence
    outputDF$tempo <- features_df$tempo
    })
  }
  return(outputDF)
}

# Function Testing
rc_df <- playlist_to_df(RapCaviar)
View(rc_df) #10 missing song lyrics


################################################################################

## New Function to pull danceablitiy, etc.

## New Function to pull danceablitiy, etc. for final 4 playlist.
playlist_to_df_other <- function(playlist){
  
  #creates df of Track Names and Pop Score
  outputDF <- data.frame(playlist[["tracks"]][["items"]][["track.name"]],playlist[["tracks"]][["items"]][["track.popularity"]], playlist[["tracks"]][["items"]][["track.id"]])
  colnames(outputDF)<-c("name","popularity","track.id")
  outputDF$name <-gsub("\\s*\\([^\\)]+\\)","",as.character(outputDF$name))
  #removes all parenthesis and everything inside them
  
  #artist name added to df
  vector1 <- character(nrow(outputDF))
  for(i in 1:nrow(outputDF)){
    vector1[i]<- playlist[["tracks"]][["items"]][["track.artists"]][[i]][["name"]][[1]]
  }
  outputDF$artist <- vector1
  
  #lyric time
  outputDF$lyrics <-NA
  
  #error handling to keep on adding to df if lyrics cannot be found
  for(i in 1:nrow(outputDF)){
    try({
      lyrics_from_genius <- genius_lyrics(artist = outputDF$artist[i],song = outputDF$name[i], info = "simple")
      lyric_list <- lyrics_from_genius$lyric
      outputDF$lyrics[i] <- paste(unlist(lyric_list),collapse=' ')
      
    })
    
  }
  
  #Adds additional track audio features to our data frame. key, energy, loudness, mode etc...
  playID <- playlist[["id"]]
  features_df <- get_playlist_audio_features("spotify",playID)
  
  mergedDF <- join(outputDF,features_df,by="track.id",type="left")
  outputMerged <- mergedDF[,c(1,2,5,11,12,13,14,15,16,17, 18,19,20,21)]
  
  
  return(outputMerged)
}

################################################################################
## Word Cloud  -----

word_cloud_from_playlist <- function(playlistID) {
  
  # Combine all lyrics from playlist
  df <- playlist_to_df(playlistID)
  playlistLyrics <- paste(unlist(df[,4]), collapse=' ')
  
  # Words in vector
  words_vec <- VectorSource(playlistLyrics)
  
  # Words in corpus
  words_corpus <- Corpus(words_vec)
  
  # Clean corpus
  words_corpus <- tm_map(words_corpus, content_transformer(tolower))
  words_corpus <- tm_map(words_corpus, removePunctuation)
  words_corpus <- tm_map(words_corpus, removeNumbers)
  words_corpus <- tm_map(words_corpus, removeWords, stopwords("english"))
  
  # Make TDM and matrix to find word frequency
  words_tdm <- TermDocumentMatrix(words_corpus)
  words_m <- as.matrix(words_tdm)
  wordCounts <- rowSums(words_m)
  wordCounts <- sort(wordCounts, decreasing = T)
  
  # Plot wordcloud
  wordCloud <- wordcloud(names(wordCounts), wordCounts, max.words = 25)
  
  return(wordCloud)
  
}

# Testing function
word_cloud_from_playlist(RapCaviar)


################################################################################
## Running Functions

# Getting song data
#df <- get_album_data("Pooh Shiesty", "shiesty season")


playlistsNames <- list(RapCaviar, MostNecessary, SignedXOXO, TodaysTopHits,
                       PopRising, RockThis, AltNOW, RockHard, KickassMetal,
                       NewCore, NuMetalGeneration, Alternative10s, EarlyAlternative,
                       Alternative00s)


list1 <- list()

for (i in 1:length(playlistsNames)) {
  
  list1[[i]] <- playlist_to_df(playlistsNames[[i]])
  
}


list2 <- list()

for (i in 1:length(playlistsNames)) {
  
  list2[[i]] <- playlist_to_df(playlistsNames[[i]])
  
}


list3 <- list()

for (i in 1:length(playlistsNames)) {
  
  list3[[i]] <- playlist_to_df_other(playlistsNames[[i]])
  
}


list4 <- list()

for (i in 1:length(playlistsNames)) {
  
  list4[[i]] <- playlist_to_df_other(playlistsNames[[i]])
  
}




playlist_names <- c("RapCaviar","MostNecessary", "SignedXOXO", "TodaysTopHits",
                   "PopRising", "RockThis", "AltNOW", "RockHard", "KickassMetal",
                   "NewCore", "NuMetalGeneration", "Alternative10s", "EarlyAlternative",
                   "Alternative00")

spotify_playlists_data <- list4

#for (i in length(spotify_playlists_data)) {
  
#  names(spotify_playlists_data)[i] <- playlist_names[i]
  
#  return(spotify_playlists_data)
  
# }

View(spotify_playlists_data)



save.image()





