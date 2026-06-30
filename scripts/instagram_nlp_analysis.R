library(tidyverse)
library(tidytext)
library(readxl)
library(ggplot2)
library(wordcloud)
library(textdata)

# Import data
ig_comments <- read_excel("instagram_comments.xlsx")

# Remove duplicate comments
ig_comments_clean <- ig_comments %>%
  distinct(text, .keep_all = TRUE)

# Tokenize comments
comments_tokens <- ig_comments_clean %>%
  unnest_tokens(word, text)

# Custom stop words
custom_stop <- tibble(
  word = c("it’s", 
           "that’s", 
           "literally", 
           "ago", 
           "day", 
           "yall", 
           "i’m",
           "york",
           "fucking",
           "shit")
)

# Remove stop words
comments_tokens_clean <- comments_tokens %>%
  anti_join(stop_words, by = "word") %>%
  anti_join(custom_stop, by = "word")

# Combine singular/plural versions
# Clean tokens for frequency-based analyses (word cloud, word counts)
comments_tokens_clean <- comments_tokens_clean %>%
  mutate(
    word = case_when(
      word == "horses" ~ "horse",
      word == "animals" ~ "animal",
      word == "carriages" ~ "carriage",
      word == "rides" ~ "ride",
      TRUE ~ word
    )
  )

# Count frequencies using final clean tokens
word_counts <- comments_tokens_clean %>%
  count(word, sort = TRUE)

# Display top 20 most frequent cleaned words
top_20 <- word_counts %>%
  slice_head(n = 20)

png("wordcloud.png", width = 10, height = 6.2, units = "in", res = 300)

wordcloud(
  words = word_counts$word,
  freq = word_counts$n,
  max.words = 50,
  random.order = FALSE,
  scale = c(3.5, 1)
)

dev.off()

# NRC Sentiment Analysis ####
nrc <- get_sentiments("nrc")

# Use original tokens for NRC emotion analysis to preserve the
# emotional language of the full comments
emotion_counts <- comments_tokens %>%
  inner_join(nrc, by = "word") %>%
  count(sentiment, sort = TRUE)

emotion_counts

emotion_counts_clean <- emotion_counts %>%
  filter(!sentiment %in% c("positive", "negative"))

nrc_plot <- emotion_counts_clean %>%
  ggplot(aes(x = reorder(sentiment, n), y = n)) +
  geom_col(fill = "darkolivegreen4") +
  geom_text(
    aes(label = n),
    hjust = -0.1,
    size = 4
  ) +
  coord_flip() +
  labs(
    title = "Emotional Tone of 7,000+ Public Comments",
    x = "Emotion",
    y = "Count",
    caption = "Based on NRC word-level emotion matches; a single comment can contain multiple emotions."
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(
      size = 18,
      face = "bold"
    ),
    axis.text.y = element_text(
      size = 13,
      face = "bold"
    ),
    axis.text.x = element_text(
      size = 11
    ),
    plot.caption = element_text(
      size = 9,
      color = "gray40",
      hjust = 1
    )
  ) +
  expand_limits(y = max(emotion_counts_clean$n) * 1.08)

nrc_plot

# Bigrams ####

bigrams <- ig_comments_clean %>%
  unnest_tokens(bigram, text, token = "ngrams", n = 2)

bigram_counts <- bigrams %>%
  count(bigram, sort = TRUE)

head(bigram_counts, 20)

bigrams_clean <- ig_comments_clean %>%
  unnest_tokens(bigram, text, token = "ngrams", n = 2) %>%
  separate(bigram, c("word1", "word2"), sep = " ") %>%
  filter(
  !is.na(word1),
  !is.na(word2),
  !word1 %in% stop_words$word,
  !word2 %in% stop_words$word,
  !word1 %in% custom_stop$word,
  !word2 %in% custom_stop$word
) %>%
  unite(bigram, word1, word2, sep = " ") %>%
  count(bigram, sort = TRUE)
bigrams_clean

bigram_plot <- bigrams_clean %>%
  filter(bigram != "na na") %>%
  slice_max(n, n = 10) %>%
  ggplot(aes(x = reorder(bigram, n), y = n)) +
  geom_col(fill = "darkslategray") +
  geom_text(
    aes(label = n),
    hjust = -0.15,
    size = 4
  ) +
  coord_flip() +
  expand_limits(y = max(bigrams_clean$n) * 1.10) +
  labs(
    title = "Most Common Two-Word Phrases",
    subtitle = "Instagram comments following the death of Central Park carriage horse Deniz",
    x = "",
    y = "Count"
  ) +
  theme_minimal() +
  theme(
    legend.position = "none",
    plot.title = element_text(size = 18, face = "bold"),
    plot.subtitle = element_text(size = 12),
    axis.text.y = element_text(size = 13, face = "bold"),
    axis.text.x = element_text(size = 11)
  )

bigram_plot

ggsave("bigram_chart.png", plot = bigram_plot, width = 10, height = 6.2, dpi = 300)

# Count mentions of NYC mayor-related terms
mayor_mentions <- comments_tokens_clean %>%
  filter(word %in% c(
    "nycmayor",
    "nycmayorsoffice",
    "mayor",
    "mamdani"
  )) %>%
  summarise(total_mentions = n())

mayor_mentions

