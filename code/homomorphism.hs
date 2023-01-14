import Data.Map.Strict (mergeWithKey, empty, member, adjust, insert, Map)

type Document = String
type WordCount = Map String Int

(<>) :: WordCount -> WordCount -> WordCount
m1 <> m2 = mergeWithKey (\k c1 c2 -> Just (c1 + c2)) id id m1 m2

countWords :: Document -> WordCount
countWords doc = let documentWords = words doc
                     includeWord wordCount word = 
                      if member word wordCount
                      then adjust (+1) word wordCount 
                      else insert word 1 wordCount
                 in foldl includeWord empty documentWords

(+++) :: Document -> Document -> Document
d1 +++ d2 = d1 ++ "\n" ++ d2

d1 = "hola camisa casa perro carro casa camisa gato"
d2 = "hola casa carro perro silla camisa gato camisa"

