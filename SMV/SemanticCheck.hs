module SemanticCheck(
   fileCheck,
   fileCheckOutput
)where
   import DataTypes
   import SMVParser
   import DataTypesOps
   import Data.List
   import Data.HasCacBDD

   fileCheck :: String -> IO()
   fileCheck file = do
                        pmod <- syntaxCheck file
                        let
                           vars     = extractVarsList pmod
                           initBDD  = initSynthesis pmod vars
                           transBDD = transSynthesis pmod vars
                           res = case (existsFairness pmod) of
                              False -> uFormulaCheck pmod transBDD vars
                              _     -> error "Algoritmo con fairness no implementado todavia"
                           verify = checkInitSat initBDD res
                        --printSolution verify
                        return ()  

   fileCheckOutput :: String -> IO ()
   fileCheckOutput file = do
                           pmod <- syntaxCheck file
                           putStrLn $ "El programa definido es: " ++ show pmod
                           let
                              vars     = extractVarsList pmod
                              initBDD  = initSynthesis pmod vars
                              transBDD = transSynthesis pmod vars
                              res = case (existsFairness pmod) of
                                       False -> uFormulaCheck pmod transBDD vars
                                       _     -> error "Algoritmo con fairness no implementado todavia"
                              verify = checkInitSat initBDD res
                           putStrLn $ "\nLos estados iniciales son: " ++ show(initBDD) ++ "\n"
                           putStrLn $ "La funcion de transicion es: " ++ show(transBDD) ++ "\n"
                           putStrLn $ "Los estados que satisfacen la formula son: " ++ show (res) ++ "\n"
                           putStrLn $ "Asignaciones: "    ++ show (map allSats res) ++ "\n"
                           putStrLn $ "Verificacion: " ++ show(verify) ++ "\n"
                           putStrLn $ "initBDD: " ++ show(initBDD) ++ "\n"
                           putStrLn $ "res: " ++ show(res) ++ "\n"
                           printSolution verify
                           return () 

   printSolution :: [Bool] -> IO ()
   printSolution xs = printSolRec 1 xs

   printSolRec :: Int -> [Bool] -> IO ()
   printSolRec _        []    = return ()
   printSolRec specnum (x:xs) =  do
                                    let 
                                       res = case x of 
                                          True  -> "\8872"
                                          False -> "\8877"
                                    putStrLn $ "Especificacion #" ++ show(specnum) ++ ": " ++ res
                                    printSolRec (specnum + 1) xs




   checkInitSat :: Bdd -> [Bdd] -> [Bool]
   checkInitSat init []       = []
   checkInitSat init (x:xs)   =  if (init `imp` x == top) 
                                 then True : checkInitSat init xs
                                 else False : checkInitSat init xs
                                 
   
   
   extractVarsList :: PModule -> [Variable]
   extractVarsList (PModule (VarDec vars) _ _ _ _) = sort vars

   initSynthesis :: PModule -> [Variable] -> Bdd
   initSynthesis (PModule _ (InitCons bsimple) _ _ _) vars = synthSimple bsimple vars

   synthSimple :: BSimple -> [Variable] -> Bdd
   synthSimple (SConst const) _  =  case const of
                                          TRUE        ->  top
                                          FALSE       ->  bot

   synthSimple (SVariable cur) vars =  case (cur `elemIndex` vars) of
                                             Just num -> var $ num*2
                                             Nothing  -> error "Variable no encontrada"

   synthSimple (SUnary Not f) vars  = neg $ synthSimple f vars

   synthSimple (SBinary bop f1 f2) vars = case bop of
                                                And   -> (synthSimple f1 vars) `con` (synthSimple f2 vars)
                                                Or    -> (synthSimple f1 vars) `dis` (synthSimple f2 vars)
                                                Xor   -> (synthSimple f1 vars) `xor` (synthSimple f2 vars)
                                                If    -> (synthSimple f1 vars) `imp` (synthSimple f2 vars)
                                                Iff   -> (synthSimple f1 vars) `equ` (synthSimple f2 vars)


   ----------------- Funciones de sintesis la relacion de transicion ------------------------------------------------
   -- Convierte la lista de expresiones en TRANS a un BDD que representa a la funcion de transicion
   transSynthesis :: PModule -> [Variable] -> Bdd
   transSynthesis (PModule _ _ (TransCons trans) _ _) varL = synthTrans trans varL

   -- Convierte uno de los renglones en TRANS a un bdd
   synthTrans :: BNext -> [Variable] -> Bdd
   synthTrans (NConst const)      _     = case const of
                                             TRUE        ->  top
                                             FALSE       ->  bot
   synthTrans (NSVariable cur)   vars  = case (cur `elemIndex` vars) of
                                             Just num    -> var $ num*2   
                                             Nothing     -> error "Variable no encontrada"

   synthTrans (NNVariable next)   vars  = case (next `elemIndex` vars) of
                                             Just num    -> var $ num*2+1   
                                             Nothing     -> error "Variable no encontrada"

   synthTrans (NUnary Not f)  vars  = neg $ synthTrans f vars

   synthTrans (NBinary bop f1 f2)  vars  =   case bop of
                                                And        -> (synthTrans f1 vars) `con` (synthTrans f2 vars)
                                                Or         -> (synthTrans f1 vars) `dis` (synthTrans f2 vars)
                                                Xor        -> (synthTrans f1 vars) `xor` (synthTrans f2 vars)
                                                If         -> (synthTrans f1 vars) `imp` (synthTrans f2 vars)
                                                Iff        -> (synthTrans f1 vars) `equ` (synthTrans f2 vars)
   ----------------- Funciones de sintesis la relacion de transicion (fin)--------------------------------------------



   ----------------- Funciones de verificacion de la formula CTL sin Fairness -----------------------------------------
   uFormulaCheck :: PModule -> Bdd -> [Variable] -> [Bdd]
   uFormulaCheck (PModule _ _ _ ctlspecs _) trans vars = uFormulaCheckL ctlspecs trans vars

   uFormulaCheckL :: [CTLSpec] -> Bdd -> [Variable] -> [Bdd]
   uFormulaCheckL [] trans vars = []
   uFormulaCheckL ((CTLSpec ctlf) : xs) trans vars = (uSubCheck ctlf trans vars) : uFormulaCheckL  xs trans vars



   uSubCheck :: CTLF -> Bdd -> [Variable] -> Bdd
   uSubCheck  (CConst const) _  _                  =  case const of
                                                         TRUE        -> top
                                                         FALSE       -> bot
   uSubCheck  (CVariable cur) _ vars               =  case (cur `elemIndex` vars) of
                                                         Just num    -> var $ num*2
                                                         Nothing     -> error "Variable no encontrada"

   uSubCheck (CBUnary Not ctlf) trans vars        =  neg $ uSubCheck ctlf trans vars

   uSubCheck (CBBinary bbinop f1 f2) trans vars   =  case bbinop of
                                                            And      -> (uSubCheck f1 trans vars) `con` (uSubCheck f2 trans vars)
                                                            Or       -> (uSubCheck f1 trans vars) `dis` (uSubCheck f2 trans vars)
                                                            Xor      -> (uSubCheck f1 trans vars) `xor` (uSubCheck f2 trans vars)
                                                            If       -> (uSubCheck f1 trans vars) `imp` (uSubCheck f2 trans vars)
                                                            Iff      -> (uSubCheck f1 trans vars) `equ` (uSubCheck f2 trans vars)
   uSubCheck (CCUnary cunop cltf)  trans vars     =      let 
                                                            sub = uSubCheck cltf trans vars
                                                         in
                                                            case cunop of
                                                               EX    -> satEX sub trans 
                                                               EG    -> satEG sub trans 
                                                               _     -> error "Formula a verificar no esta en ENF"
   uSubCheck (CCBinary cbinop f1 f2) trans vars   =      let
                                                            sub1 = uSubCheck f1 trans vars
                                                            sub2 = uSubCheck f2 trans vars
                                                         in
                                                            case cbinop of
                                                               EU    -> satEU sub1 sub2 trans
                                                               _     -> error "Formula a verificar no esta en ENF"
   ----------------- Funciones de verificacion de la formula CTL sin Fairness (fin)-----------------------------------------
   {-
      Funcion que obtiene, dado un conjunto de estados, el conjunto de estados que se encuentran a un paso de este:
      Dado B, se obtiene EX(B)                                                  
   -}
   satEX :: Bdd -> Bdd -> Bdd
   satEX subf trans  = let
                              nextsubf    = renameNextBdd subf -- X_B{x' <- x}
                              transnext   = con trans nextsubf -- Delta & nextsubf 
                              nextvars    = [a | a <- (allVarsOfSorted transnext), a `mod` 2 == 1] -- Todas las variables next en transnext
                           in
                              existsSet nextvars transnext



   satEG :: Bdd -> Bdd -> Bdd
   satEG fj trans =   let
                           aux      = satEX fj trans
                           fjp1     = fj `con` aux
                        in
                           if (fj `equ` fjp1) == top 
                              then fjp1
                              else satEG fjp1 trans

                              

   satEU :: Bdd -> Bdd -> Bdd -> Bdd
   satEU fc fj trans =  let
                           postj = satEX fj trans
                           term  = fc `con` postj
                           fjp1  = fj `dis` term
                        in
                           if(fj `equ` fjp1) == top
                              then fjp1
                              else satEU fc fjp1 trans


   -- Recibe un Bdd y cambia todas sus variables por la siguiente f{x'<-x}
   renameNextBdd :: Bdd -> Bdd
   renameNextBdd orig      =  let 
                                 varbdd = allVarsOfSorted orig
                                 mapping = renameNextList varbdd
                              in
                                 relabel mapping orig

   renameNextList :: [Int] -> [(Int, Int)]
   renameNextList vars = [(a,b) | a <- vars, let b = a+1]

   existsFairness :: PModule -> Bool
   existsFairness (PModule _ _ _ _ Nothing) = False
   existsFairness (PModule _ _ _ _ (Just _)) = True


{-
   ----------------- Funciones de verificacion de la formula CTL con Fairness -----------------------------------------
   fFormulaCheck :: Program -> Bdd -> [Variable] -> Bdd
   fFormulaCheck (Program _ _ _ (CTLS ctlf) (Just fair)) trans vars =   let
                                                                           fairl = synthFairness fair vars
                                                                           fairst = fairStates trans fairl
                                                                           ctlfFair = fSubCheck ctlf trans fairl vars
                                                                        in
                                                                           fairst `con` ctlfFair
                                                                           

   fSubCheck :: CTLF -> Bdd -> [Bdd]-> [Variable] -> Bdd
   fSubCheck (CConst const) _ _ _      =  case const of
                                             TRUE  -> top
                                             FALSE -> bot
   fSubCheck (CVariable cur) _ _ vars  =  case (cur `elemIndex` vars) of
                                             Just num -> var $ num*2
                                             Nothing  -> error "Variable no encontrada"

   fSubCheck (CBUnary Not ctlf) trans fairs vars = neg $ fSubCheck ctlf trans fairs vars

   fSubCheck (CBBinary bbinop f1 f2) trans fairs vars = case bbinop of
                                                            And   -> (fSubCheck f1 trans fairs vars) `con` (fSubCheck f2 trans fairs vars)
                                                            Or    -> (fSubCheck f1 trans fairs vars) `dis` (fSubCheck f2 trans fairs vars)
                                                            If    -> (fSubCheck f1 trans fairs vars) `imp` (fSubCheck f2 trans fairs vars)
                                                            Iff   -> (fSubCheck f1 trans fairs vars) `equ` (fSubCheck f2 trans fairs vars)
   fSubCheck (CCUnary EX ctlf) trans fairs vars =  let
                                                      sub = fSubCheck ctlf trans fairs vars
                                                      statefair = fairStates trans fairs
                                                   in
                                                      satEX (sub `con` statefair) trans
   fSubCheck (CCBinary cbinop f1 f2) trans fairs vars =  let
                                                            sub1 = fSubCheck f1 trans fairs vars
                                                            sub2 = fSubCheck f2 trans fairs vars
                                                            statefair = fairStates trans fairs
                                                         in
                                                            satEU sub1 (sub2 `con` statefair) trans

   fSubCheck (CCUnary EG ctlf) trans fairs vars =  let
                                                      sub = fSubCheck ctlf trans fairs vars
                                                   in
                                                      satEG sub trans 



   fairStates :: Bdd -> [Bdd] -> Bdd
   fairStates trans xs = satEGFair top trans xs 

   satEGFair :: Bdd -> Bdd -> [Bdd] -> Bdd
   satEGFair subf trans xs = satEGFairA subf subf trans xs


   satEGFairA :: Bdd -> Bdd -> Bdd -> [Bdd] -> Bdd
   satEGFairA subf fixed trans xs =  let
                                       bigconj = satEGFairCon subf trans fixed xs
                                       fixedp = subf `con` bigconj
                                    in
                                       if (fixedp `equ` fixed) == top
                                          then fixed
                                          else satEGFairA subf fixedp trans xs


   -- Realiza la conjuncion iterada de 
   satEGFairCon :: Bdd -> Bdd -> Bdd -> [Bdd]  -> Bdd
   satEGFairCon subf trans fixed []  = top
   satEGFairCon subf trans fixed (x:xs)  = let
                                             eu = satEU subf (fixed `con` x) trans
                                             ex = satEX eu trans
                                          in
                                             ex `con` (satEGFairCon subf trans fixed xs)

   synthFairness :: Fair -> [Variable] -> [Bdd]
   synthFairness (Fair xs) vars = synthFairList xs vars


   synthFairList :: [BSimple] -> [Variable] -> [Bdd]
   synthFairList [] _ = []
   synthFairList (x:xs) vars = (synthOneSimple x vars) : synthFairList xs vars








   ----------------- Funciones de verificacion de la formula CTL con Fairness (fin) -----------------------------------------
-}