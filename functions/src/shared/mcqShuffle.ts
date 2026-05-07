export function mcqShuffle(
  options: string[],
  correctIndex: number,
): {shuffledOptions: string[]; shuffledCorrectIndex: number} {
  if (options.length !== 4) {
    throw new Error("options_must_have_length_4");
  }
  if (
    !Number.isInteger(correctIndex) ||
    correctIndex < 0 ||
    correctIndex >= options.length
  ) {
    throw new Error("correct_index_out_of_range");
  }

  const shuffledOptions = [...options];
  let shuffledCorrectIndex = correctIndex;

  for (let i = shuffledOptions.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffledOptions[i], shuffledOptions[j]] = [
      shuffledOptions[j],
      shuffledOptions[i],
    ];

    if (i === shuffledCorrectIndex) {
      shuffledCorrectIndex = j;
    } else if (j === shuffledCorrectIndex) {
      shuffledCorrectIndex = i;
    }
  }

  return {shuffledOptions, shuffledCorrectIndex};
}
