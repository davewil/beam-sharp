-module(g_dup_200).
-export(['Fun1'/1, fun_1/1, 'Fun2'/1, fun_2/1, 'Fun3'/1, fun_3/1, 'Fun4'/1, fun_4/1, 'Fun5'/1, fun_5/1, 'Fun6'/1, fun_6/1, 'Fun7'/1, fun_7/1, 'Fun8'/1, fun_8/1, 'Fun9'/1, fun_9/1, 'Fun10'/1, fun_10/1, 'Fun11'/1, fun_11/1, 'Fun12'/1, fun_12/1, 'Fun13'/1, fun_13/1, 'Fun14'/1, fun_14/1, 'Fun15'/1, fun_15/1, 'Fun16'/1, fun_16/1, 'Fun17'/1, fun_17/1, 'Fun18'/1, fun_18/1, 'Fun19'/1, fun_19/1, 'Fun20'/1, fun_20/1, 'Fun21'/1, fun_21/1, 'Fun22'/1, fun_22/1, 'Fun23'/1, fun_23/1, 'Fun24'/1, fun_24/1, 'Fun25'/1, fun_25/1, 'Fun26'/1, fun_26/1, 'Fun27'/1, fun_27/1, 'Fun28'/1, fun_28/1, 'Fun29'/1, fun_29/1, 'Fun30'/1, fun_30/1, 'Fun31'/1, fun_31/1, 'Fun32'/1, fun_32/1, 'Fun33'/1, fun_33/1, 'Fun34'/1, fun_34/1, 'Fun35'/1, fun_35/1, 'Fun36'/1, fun_36/1, 'Fun37'/1, fun_37/1, 'Fun38'/1, fun_38/1, 'Fun39'/1, fun_39/1, 'Fun40'/1, fun_40/1, 'Fun41'/1, fun_41/1, 'Fun42'/1, fun_42/1, 'Fun43'/1, fun_43/1, 'Fun44'/1, fun_44/1, 'Fun45'/1, fun_45/1, 'Fun46'/1, fun_46/1, 'Fun47'/1, fun_47/1, 'Fun48'/1, fun_48/1, 'Fun49'/1, fun_49/1, 'Fun50'/1, fun_50/1, 'Fun51'/1, fun_51/1, 'Fun52'/1, fun_52/1, 'Fun53'/1, fun_53/1, 'Fun54'/1, fun_54/1, 'Fun55'/1, fun_55/1, 'Fun56'/1, fun_56/1, 'Fun57'/1, fun_57/1, 'Fun58'/1, fun_58/1, 'Fun59'/1, fun_59/1, 'Fun60'/1, fun_60/1, 'Fun61'/1, fun_61/1, 'Fun62'/1, fun_62/1, 'Fun63'/1, fun_63/1, 'Fun64'/1, fun_64/1, 'Fun65'/1, fun_65/1, 'Fun66'/1, fun_66/1, 'Fun67'/1, fun_67/1, 'Fun68'/1, fun_68/1, 'Fun69'/1, fun_69/1, 'Fun70'/1, fun_70/1, 'Fun71'/1, fun_71/1, 'Fun72'/1, fun_72/1, 'Fun73'/1, fun_73/1, 'Fun74'/1, fun_74/1, 'Fun75'/1, fun_75/1, 'Fun76'/1, fun_76/1, 'Fun77'/1, fun_77/1, 'Fun78'/1, fun_78/1, 'Fun79'/1, fun_79/1, 'Fun80'/1, fun_80/1, 'Fun81'/1, fun_81/1, 'Fun82'/1, fun_82/1, 'Fun83'/1, fun_83/1, 'Fun84'/1, fun_84/1, 'Fun85'/1, fun_85/1, 'Fun86'/1, fun_86/1, 'Fun87'/1, fun_87/1, 'Fun88'/1, fun_88/1, 'Fun89'/1, fun_89/1, 'Fun90'/1, fun_90/1, 'Fun91'/1, fun_91/1, 'Fun92'/1, fun_92/1, 'Fun93'/1, fun_93/1, 'Fun94'/1, fun_94/1, 'Fun95'/1, fun_95/1, 'Fun96'/1, fun_96/1, 'Fun97'/1, fun_97/1, 'Fun98'/1, fun_98/1, 'Fun99'/1, fun_99/1, 'Fun100'/1, fun_100/1, 'Fun101'/1, fun_101/1, 'Fun102'/1, fun_102/1, 'Fun103'/1, fun_103/1, 'Fun104'/1, fun_104/1, 'Fun105'/1, fun_105/1, 'Fun106'/1, fun_106/1, 'Fun107'/1, fun_107/1, 'Fun108'/1, fun_108/1, 'Fun109'/1, fun_109/1, 'Fun110'/1, fun_110/1, 'Fun111'/1, fun_111/1, 'Fun112'/1, fun_112/1, 'Fun113'/1, fun_113/1, 'Fun114'/1, fun_114/1, 'Fun115'/1, fun_115/1, 'Fun116'/1, fun_116/1, 'Fun117'/1, fun_117/1, 'Fun118'/1, fun_118/1, 'Fun119'/1, fun_119/1, 'Fun120'/1, fun_120/1, 'Fun121'/1, fun_121/1, 'Fun122'/1, fun_122/1, 'Fun123'/1, fun_123/1, 'Fun124'/1, fun_124/1, 'Fun125'/1, fun_125/1, 'Fun126'/1, fun_126/1, 'Fun127'/1, fun_127/1, 'Fun128'/1, fun_128/1, 'Fun129'/1, fun_129/1, 'Fun130'/1, fun_130/1, 'Fun131'/1, fun_131/1, 'Fun132'/1, fun_132/1, 'Fun133'/1, fun_133/1, 'Fun134'/1, fun_134/1, 'Fun135'/1, fun_135/1, 'Fun136'/1, fun_136/1, 'Fun137'/1, fun_137/1, 'Fun138'/1, fun_138/1, 'Fun139'/1, fun_139/1, 'Fun140'/1, fun_140/1, 'Fun141'/1, fun_141/1, 'Fun142'/1, fun_142/1, 'Fun143'/1, fun_143/1, 'Fun144'/1, fun_144/1, 'Fun145'/1, fun_145/1, 'Fun146'/1, fun_146/1, 'Fun147'/1, fun_147/1, 'Fun148'/1, fun_148/1, 'Fun149'/1, fun_149/1, 'Fun150'/1, fun_150/1, 'Fun151'/1, fun_151/1, 'Fun152'/1, fun_152/1, 'Fun153'/1, fun_153/1, 'Fun154'/1, fun_154/1, 'Fun155'/1, fun_155/1, 'Fun156'/1, fun_156/1, 'Fun157'/1, fun_157/1, 'Fun158'/1, fun_158/1, 'Fun159'/1, fun_159/1, 'Fun160'/1, fun_160/1, 'Fun161'/1, fun_161/1, 'Fun162'/1, fun_162/1, 'Fun163'/1, fun_163/1, 'Fun164'/1, fun_164/1, 'Fun165'/1, fun_165/1, 'Fun166'/1, fun_166/1, 'Fun167'/1, fun_167/1, 'Fun168'/1, fun_168/1, 'Fun169'/1, fun_169/1, 'Fun170'/1, fun_170/1, 'Fun171'/1, fun_171/1, 'Fun172'/1, fun_172/1, 'Fun173'/1, fun_173/1, 'Fun174'/1, fun_174/1, 'Fun175'/1, fun_175/1, 'Fun176'/1, fun_176/1, 'Fun177'/1, fun_177/1, 'Fun178'/1, fun_178/1, 'Fun179'/1, fun_179/1, 'Fun180'/1, fun_180/1, 'Fun181'/1, fun_181/1, 'Fun182'/1, fun_182/1, 'Fun183'/1, fun_183/1, 'Fun184'/1, fun_184/1, 'Fun185'/1, fun_185/1, 'Fun186'/1, fun_186/1, 'Fun187'/1, fun_187/1, 'Fun188'/1, fun_188/1, 'Fun189'/1, fun_189/1, 'Fun190'/1, fun_190/1, 'Fun191'/1, fun_191/1, 'Fun192'/1, fun_192/1, 'Fun193'/1, fun_193/1, 'Fun194'/1, fun_194/1, 'Fun195'/1, fun_195/1, 'Fun196'/1, fun_196/1, 'Fun197'/1, fun_197/1, 'Fun198'/1, fun_198/1, 'Fun199'/1, fun_199/1, 'Fun200'/1, fun_200/1]).
'Fun1'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 1};
'Fun1'(_) -> error.
fun_1(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 1};
fun_1(_) -> error.
'Fun2'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 2};
'Fun2'(_) -> error.
fun_2(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 2};
fun_2(_) -> error.
'Fun3'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 3};
'Fun3'(_) -> error.
fun_3(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 3};
fun_3(_) -> error.
'Fun4'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 4};
'Fun4'(_) -> error.
fun_4(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 4};
fun_4(_) -> error.
'Fun5'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 5};
'Fun5'(_) -> error.
fun_5(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 5};
fun_5(_) -> error.
'Fun6'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 6};
'Fun6'(_) -> error.
fun_6(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 6};
fun_6(_) -> error.
'Fun7'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 7};
'Fun7'(_) -> error.
fun_7(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 7};
fun_7(_) -> error.
'Fun8'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 8};
'Fun8'(_) -> error.
fun_8(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 8};
fun_8(_) -> error.
'Fun9'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 9};
'Fun9'(_) -> error.
fun_9(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 9};
fun_9(_) -> error.
'Fun10'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 10};
'Fun10'(_) -> error.
fun_10(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 10};
fun_10(_) -> error.
'Fun11'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 11};
'Fun11'(_) -> error.
fun_11(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 11};
fun_11(_) -> error.
'Fun12'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 12};
'Fun12'(_) -> error.
fun_12(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 12};
fun_12(_) -> error.
'Fun13'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 13};
'Fun13'(_) -> error.
fun_13(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 13};
fun_13(_) -> error.
'Fun14'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 14};
'Fun14'(_) -> error.
fun_14(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 14};
fun_14(_) -> error.
'Fun15'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 15};
'Fun15'(_) -> error.
fun_15(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 15};
fun_15(_) -> error.
'Fun16'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 16};
'Fun16'(_) -> error.
fun_16(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 16};
fun_16(_) -> error.
'Fun17'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 17};
'Fun17'(_) -> error.
fun_17(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 17};
fun_17(_) -> error.
'Fun18'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 18};
'Fun18'(_) -> error.
fun_18(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 18};
fun_18(_) -> error.
'Fun19'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 19};
'Fun19'(_) -> error.
fun_19(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 19};
fun_19(_) -> error.
'Fun20'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 20};
'Fun20'(_) -> error.
fun_20(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 20};
fun_20(_) -> error.
'Fun21'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 21};
'Fun21'(_) -> error.
fun_21(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 21};
fun_21(_) -> error.
'Fun22'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 22};
'Fun22'(_) -> error.
fun_22(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 22};
fun_22(_) -> error.
'Fun23'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 23};
'Fun23'(_) -> error.
fun_23(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 23};
fun_23(_) -> error.
'Fun24'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 24};
'Fun24'(_) -> error.
fun_24(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 24};
fun_24(_) -> error.
'Fun25'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 25};
'Fun25'(_) -> error.
fun_25(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 25};
fun_25(_) -> error.
'Fun26'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 26};
'Fun26'(_) -> error.
fun_26(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 26};
fun_26(_) -> error.
'Fun27'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 27};
'Fun27'(_) -> error.
fun_27(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 27};
fun_27(_) -> error.
'Fun28'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 28};
'Fun28'(_) -> error.
fun_28(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 28};
fun_28(_) -> error.
'Fun29'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 29};
'Fun29'(_) -> error.
fun_29(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 29};
fun_29(_) -> error.
'Fun30'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 30};
'Fun30'(_) -> error.
fun_30(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 30};
fun_30(_) -> error.
'Fun31'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 31};
'Fun31'(_) -> error.
fun_31(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 31};
fun_31(_) -> error.
'Fun32'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 32};
'Fun32'(_) -> error.
fun_32(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 32};
fun_32(_) -> error.
'Fun33'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 33};
'Fun33'(_) -> error.
fun_33(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 33};
fun_33(_) -> error.
'Fun34'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 34};
'Fun34'(_) -> error.
fun_34(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 34};
fun_34(_) -> error.
'Fun35'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 35};
'Fun35'(_) -> error.
fun_35(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 35};
fun_35(_) -> error.
'Fun36'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 36};
'Fun36'(_) -> error.
fun_36(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 36};
fun_36(_) -> error.
'Fun37'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 37};
'Fun37'(_) -> error.
fun_37(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 37};
fun_37(_) -> error.
'Fun38'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 38};
'Fun38'(_) -> error.
fun_38(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 38};
fun_38(_) -> error.
'Fun39'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 39};
'Fun39'(_) -> error.
fun_39(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 39};
fun_39(_) -> error.
'Fun40'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 40};
'Fun40'(_) -> error.
fun_40(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 40};
fun_40(_) -> error.
'Fun41'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 41};
'Fun41'(_) -> error.
fun_41(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 41};
fun_41(_) -> error.
'Fun42'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 42};
'Fun42'(_) -> error.
fun_42(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 42};
fun_42(_) -> error.
'Fun43'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 43};
'Fun43'(_) -> error.
fun_43(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 43};
fun_43(_) -> error.
'Fun44'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 44};
'Fun44'(_) -> error.
fun_44(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 44};
fun_44(_) -> error.
'Fun45'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 45};
'Fun45'(_) -> error.
fun_45(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 45};
fun_45(_) -> error.
'Fun46'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 46};
'Fun46'(_) -> error.
fun_46(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 46};
fun_46(_) -> error.
'Fun47'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 47};
'Fun47'(_) -> error.
fun_47(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 47};
fun_47(_) -> error.
'Fun48'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 48};
'Fun48'(_) -> error.
fun_48(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 48};
fun_48(_) -> error.
'Fun49'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 49};
'Fun49'(_) -> error.
fun_49(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 49};
fun_49(_) -> error.
'Fun50'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 50};
'Fun50'(_) -> error.
fun_50(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 50};
fun_50(_) -> error.
'Fun51'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 51};
'Fun51'(_) -> error.
fun_51(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 51};
fun_51(_) -> error.
'Fun52'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 52};
'Fun52'(_) -> error.
fun_52(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 52};
fun_52(_) -> error.
'Fun53'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 53};
'Fun53'(_) -> error.
fun_53(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 53};
fun_53(_) -> error.
'Fun54'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 54};
'Fun54'(_) -> error.
fun_54(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 54};
fun_54(_) -> error.
'Fun55'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 55};
'Fun55'(_) -> error.
fun_55(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 55};
fun_55(_) -> error.
'Fun56'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 56};
'Fun56'(_) -> error.
fun_56(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 56};
fun_56(_) -> error.
'Fun57'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 57};
'Fun57'(_) -> error.
fun_57(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 57};
fun_57(_) -> error.
'Fun58'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 58};
'Fun58'(_) -> error.
fun_58(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 58};
fun_58(_) -> error.
'Fun59'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 59};
'Fun59'(_) -> error.
fun_59(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 59};
fun_59(_) -> error.
'Fun60'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 60};
'Fun60'(_) -> error.
fun_60(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 60};
fun_60(_) -> error.
'Fun61'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 61};
'Fun61'(_) -> error.
fun_61(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 61};
fun_61(_) -> error.
'Fun62'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 62};
'Fun62'(_) -> error.
fun_62(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 62};
fun_62(_) -> error.
'Fun63'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 63};
'Fun63'(_) -> error.
fun_63(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 63};
fun_63(_) -> error.
'Fun64'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 64};
'Fun64'(_) -> error.
fun_64(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 64};
fun_64(_) -> error.
'Fun65'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 65};
'Fun65'(_) -> error.
fun_65(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 65};
fun_65(_) -> error.
'Fun66'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 66};
'Fun66'(_) -> error.
fun_66(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 66};
fun_66(_) -> error.
'Fun67'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 67};
'Fun67'(_) -> error.
fun_67(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 67};
fun_67(_) -> error.
'Fun68'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 68};
'Fun68'(_) -> error.
fun_68(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 68};
fun_68(_) -> error.
'Fun69'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 69};
'Fun69'(_) -> error.
fun_69(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 69};
fun_69(_) -> error.
'Fun70'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 70};
'Fun70'(_) -> error.
fun_70(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 70};
fun_70(_) -> error.
'Fun71'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 71};
'Fun71'(_) -> error.
fun_71(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 71};
fun_71(_) -> error.
'Fun72'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 72};
'Fun72'(_) -> error.
fun_72(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 72};
fun_72(_) -> error.
'Fun73'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 73};
'Fun73'(_) -> error.
fun_73(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 73};
fun_73(_) -> error.
'Fun74'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 74};
'Fun74'(_) -> error.
fun_74(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 74};
fun_74(_) -> error.
'Fun75'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 75};
'Fun75'(_) -> error.
fun_75(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 75};
fun_75(_) -> error.
'Fun76'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 76};
'Fun76'(_) -> error.
fun_76(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 76};
fun_76(_) -> error.
'Fun77'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 77};
'Fun77'(_) -> error.
fun_77(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 77};
fun_77(_) -> error.
'Fun78'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 78};
'Fun78'(_) -> error.
fun_78(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 78};
fun_78(_) -> error.
'Fun79'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 79};
'Fun79'(_) -> error.
fun_79(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 79};
fun_79(_) -> error.
'Fun80'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 80};
'Fun80'(_) -> error.
fun_80(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 80};
fun_80(_) -> error.
'Fun81'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 81};
'Fun81'(_) -> error.
fun_81(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 81};
fun_81(_) -> error.
'Fun82'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 82};
'Fun82'(_) -> error.
fun_82(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 82};
fun_82(_) -> error.
'Fun83'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 83};
'Fun83'(_) -> error.
fun_83(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 83};
fun_83(_) -> error.
'Fun84'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 84};
'Fun84'(_) -> error.
fun_84(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 84};
fun_84(_) -> error.
'Fun85'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 85};
'Fun85'(_) -> error.
fun_85(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 85};
fun_85(_) -> error.
'Fun86'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 86};
'Fun86'(_) -> error.
fun_86(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 86};
fun_86(_) -> error.
'Fun87'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 87};
'Fun87'(_) -> error.
fun_87(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 87};
fun_87(_) -> error.
'Fun88'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 88};
'Fun88'(_) -> error.
fun_88(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 88};
fun_88(_) -> error.
'Fun89'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 89};
'Fun89'(_) -> error.
fun_89(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 89};
fun_89(_) -> error.
'Fun90'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 90};
'Fun90'(_) -> error.
fun_90(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 90};
fun_90(_) -> error.
'Fun91'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 91};
'Fun91'(_) -> error.
fun_91(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 91};
fun_91(_) -> error.
'Fun92'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 92};
'Fun92'(_) -> error.
fun_92(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 92};
fun_92(_) -> error.
'Fun93'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 93};
'Fun93'(_) -> error.
fun_93(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 93};
fun_93(_) -> error.
'Fun94'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 94};
'Fun94'(_) -> error.
fun_94(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 94};
fun_94(_) -> error.
'Fun95'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 95};
'Fun95'(_) -> error.
fun_95(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 95};
fun_95(_) -> error.
'Fun96'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 96};
'Fun96'(_) -> error.
fun_96(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 96};
fun_96(_) -> error.
'Fun97'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 97};
'Fun97'(_) -> error.
fun_97(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 97};
fun_97(_) -> error.
'Fun98'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 98};
'Fun98'(_) -> error.
fun_98(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 98};
fun_98(_) -> error.
'Fun99'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 99};
'Fun99'(_) -> error.
fun_99(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 99};
fun_99(_) -> error.
'Fun100'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 100};
'Fun100'(_) -> error.
fun_100(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 100};
fun_100(_) -> error.
'Fun101'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 101};
'Fun101'(_) -> error.
fun_101(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 101};
fun_101(_) -> error.
'Fun102'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 102};
'Fun102'(_) -> error.
fun_102(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 102};
fun_102(_) -> error.
'Fun103'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 103};
'Fun103'(_) -> error.
fun_103(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 103};
fun_103(_) -> error.
'Fun104'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 104};
'Fun104'(_) -> error.
fun_104(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 104};
fun_104(_) -> error.
'Fun105'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 105};
'Fun105'(_) -> error.
fun_105(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 105};
fun_105(_) -> error.
'Fun106'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 106};
'Fun106'(_) -> error.
fun_106(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 106};
fun_106(_) -> error.
'Fun107'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 107};
'Fun107'(_) -> error.
fun_107(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 107};
fun_107(_) -> error.
'Fun108'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 108};
'Fun108'(_) -> error.
fun_108(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 108};
fun_108(_) -> error.
'Fun109'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 109};
'Fun109'(_) -> error.
fun_109(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 109};
fun_109(_) -> error.
'Fun110'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 110};
'Fun110'(_) -> error.
fun_110(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 110};
fun_110(_) -> error.
'Fun111'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 111};
'Fun111'(_) -> error.
fun_111(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 111};
fun_111(_) -> error.
'Fun112'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 112};
'Fun112'(_) -> error.
fun_112(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 112};
fun_112(_) -> error.
'Fun113'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 113};
'Fun113'(_) -> error.
fun_113(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 113};
fun_113(_) -> error.
'Fun114'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 114};
'Fun114'(_) -> error.
fun_114(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 114};
fun_114(_) -> error.
'Fun115'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 115};
'Fun115'(_) -> error.
fun_115(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 115};
fun_115(_) -> error.
'Fun116'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 116};
'Fun116'(_) -> error.
fun_116(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 116};
fun_116(_) -> error.
'Fun117'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 117};
'Fun117'(_) -> error.
fun_117(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 117};
fun_117(_) -> error.
'Fun118'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 118};
'Fun118'(_) -> error.
fun_118(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 118};
fun_118(_) -> error.
'Fun119'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 119};
'Fun119'(_) -> error.
fun_119(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 119};
fun_119(_) -> error.
'Fun120'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 120};
'Fun120'(_) -> error.
fun_120(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 120};
fun_120(_) -> error.
'Fun121'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 121};
'Fun121'(_) -> error.
fun_121(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 121};
fun_121(_) -> error.
'Fun122'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 122};
'Fun122'(_) -> error.
fun_122(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 122};
fun_122(_) -> error.
'Fun123'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 123};
'Fun123'(_) -> error.
fun_123(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 123};
fun_123(_) -> error.
'Fun124'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 124};
'Fun124'(_) -> error.
fun_124(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 124};
fun_124(_) -> error.
'Fun125'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 125};
'Fun125'(_) -> error.
fun_125(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 125};
fun_125(_) -> error.
'Fun126'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 126};
'Fun126'(_) -> error.
fun_126(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 126};
fun_126(_) -> error.
'Fun127'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 127};
'Fun127'(_) -> error.
fun_127(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 127};
fun_127(_) -> error.
'Fun128'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 128};
'Fun128'(_) -> error.
fun_128(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 128};
fun_128(_) -> error.
'Fun129'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 129};
'Fun129'(_) -> error.
fun_129(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 129};
fun_129(_) -> error.
'Fun130'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 130};
'Fun130'(_) -> error.
fun_130(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 130};
fun_130(_) -> error.
'Fun131'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 131};
'Fun131'(_) -> error.
fun_131(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 131};
fun_131(_) -> error.
'Fun132'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 132};
'Fun132'(_) -> error.
fun_132(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 132};
fun_132(_) -> error.
'Fun133'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 133};
'Fun133'(_) -> error.
fun_133(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 133};
fun_133(_) -> error.
'Fun134'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 134};
'Fun134'(_) -> error.
fun_134(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 134};
fun_134(_) -> error.
'Fun135'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 135};
'Fun135'(_) -> error.
fun_135(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 135};
fun_135(_) -> error.
'Fun136'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 136};
'Fun136'(_) -> error.
fun_136(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 136};
fun_136(_) -> error.
'Fun137'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 137};
'Fun137'(_) -> error.
fun_137(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 137};
fun_137(_) -> error.
'Fun138'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 138};
'Fun138'(_) -> error.
fun_138(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 138};
fun_138(_) -> error.
'Fun139'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 139};
'Fun139'(_) -> error.
fun_139(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 139};
fun_139(_) -> error.
'Fun140'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 140};
'Fun140'(_) -> error.
fun_140(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 140};
fun_140(_) -> error.
'Fun141'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 141};
'Fun141'(_) -> error.
fun_141(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 141};
fun_141(_) -> error.
'Fun142'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 142};
'Fun142'(_) -> error.
fun_142(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 142};
fun_142(_) -> error.
'Fun143'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 143};
'Fun143'(_) -> error.
fun_143(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 143};
fun_143(_) -> error.
'Fun144'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 144};
'Fun144'(_) -> error.
fun_144(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 144};
fun_144(_) -> error.
'Fun145'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 145};
'Fun145'(_) -> error.
fun_145(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 145};
fun_145(_) -> error.
'Fun146'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 146};
'Fun146'(_) -> error.
fun_146(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 146};
fun_146(_) -> error.
'Fun147'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 147};
'Fun147'(_) -> error.
fun_147(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 147};
fun_147(_) -> error.
'Fun148'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 148};
'Fun148'(_) -> error.
fun_148(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 148};
fun_148(_) -> error.
'Fun149'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 149};
'Fun149'(_) -> error.
fun_149(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 149};
fun_149(_) -> error.
'Fun150'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 150};
'Fun150'(_) -> error.
fun_150(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 150};
fun_150(_) -> error.
'Fun151'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 151};
'Fun151'(_) -> error.
fun_151(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 151};
fun_151(_) -> error.
'Fun152'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 152};
'Fun152'(_) -> error.
fun_152(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 152};
fun_152(_) -> error.
'Fun153'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 153};
'Fun153'(_) -> error.
fun_153(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 153};
fun_153(_) -> error.
'Fun154'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 154};
'Fun154'(_) -> error.
fun_154(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 154};
fun_154(_) -> error.
'Fun155'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 155};
'Fun155'(_) -> error.
fun_155(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 155};
fun_155(_) -> error.
'Fun156'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 156};
'Fun156'(_) -> error.
fun_156(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 156};
fun_156(_) -> error.
'Fun157'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 157};
'Fun157'(_) -> error.
fun_157(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 157};
fun_157(_) -> error.
'Fun158'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 158};
'Fun158'(_) -> error.
fun_158(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 158};
fun_158(_) -> error.
'Fun159'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 159};
'Fun159'(_) -> error.
fun_159(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 159};
fun_159(_) -> error.
'Fun160'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 160};
'Fun160'(_) -> error.
fun_160(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 160};
fun_160(_) -> error.
'Fun161'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 161};
'Fun161'(_) -> error.
fun_161(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 161};
fun_161(_) -> error.
'Fun162'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 162};
'Fun162'(_) -> error.
fun_162(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 162};
fun_162(_) -> error.
'Fun163'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 163};
'Fun163'(_) -> error.
fun_163(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 163};
fun_163(_) -> error.
'Fun164'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 164};
'Fun164'(_) -> error.
fun_164(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 164};
fun_164(_) -> error.
'Fun165'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 165};
'Fun165'(_) -> error.
fun_165(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 165};
fun_165(_) -> error.
'Fun166'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 166};
'Fun166'(_) -> error.
fun_166(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 166};
fun_166(_) -> error.
'Fun167'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 167};
'Fun167'(_) -> error.
fun_167(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 167};
fun_167(_) -> error.
'Fun168'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 168};
'Fun168'(_) -> error.
fun_168(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 168};
fun_168(_) -> error.
'Fun169'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 169};
'Fun169'(_) -> error.
fun_169(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 169};
fun_169(_) -> error.
'Fun170'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 170};
'Fun170'(_) -> error.
fun_170(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 170};
fun_170(_) -> error.
'Fun171'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 171};
'Fun171'(_) -> error.
fun_171(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 171};
fun_171(_) -> error.
'Fun172'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 172};
'Fun172'(_) -> error.
fun_172(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 172};
fun_172(_) -> error.
'Fun173'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 173};
'Fun173'(_) -> error.
fun_173(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 173};
fun_173(_) -> error.
'Fun174'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 174};
'Fun174'(_) -> error.
fun_174(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 174};
fun_174(_) -> error.
'Fun175'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 175};
'Fun175'(_) -> error.
fun_175(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 175};
fun_175(_) -> error.
'Fun176'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 176};
'Fun176'(_) -> error.
fun_176(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 176};
fun_176(_) -> error.
'Fun177'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 177};
'Fun177'(_) -> error.
fun_177(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 177};
fun_177(_) -> error.
'Fun178'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 178};
'Fun178'(_) -> error.
fun_178(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 178};
fun_178(_) -> error.
'Fun179'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 179};
'Fun179'(_) -> error.
fun_179(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 179};
fun_179(_) -> error.
'Fun180'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 180};
'Fun180'(_) -> error.
fun_180(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 180};
fun_180(_) -> error.
'Fun181'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 181};
'Fun181'(_) -> error.
fun_181(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 181};
fun_181(_) -> error.
'Fun182'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 182};
'Fun182'(_) -> error.
fun_182(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 182};
fun_182(_) -> error.
'Fun183'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 183};
'Fun183'(_) -> error.
fun_183(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 183};
fun_183(_) -> error.
'Fun184'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 184};
'Fun184'(_) -> error.
fun_184(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 184};
fun_184(_) -> error.
'Fun185'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 185};
'Fun185'(_) -> error.
fun_185(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 185};
fun_185(_) -> error.
'Fun186'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 186};
'Fun186'(_) -> error.
fun_186(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 186};
fun_186(_) -> error.
'Fun187'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 187};
'Fun187'(_) -> error.
fun_187(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 187};
fun_187(_) -> error.
'Fun188'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 188};
'Fun188'(_) -> error.
fun_188(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 188};
fun_188(_) -> error.
'Fun189'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 189};
'Fun189'(_) -> error.
fun_189(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 189};
fun_189(_) -> error.
'Fun190'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 190};
'Fun190'(_) -> error.
fun_190(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 190};
fun_190(_) -> error.
'Fun191'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 191};
'Fun191'(_) -> error.
fun_191(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 191};
fun_191(_) -> error.
'Fun192'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 192};
'Fun192'(_) -> error.
fun_192(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 192};
fun_192(_) -> error.
'Fun193'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 193};
'Fun193'(_) -> error.
fun_193(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 193};
fun_193(_) -> error.
'Fun194'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 194};
'Fun194'(_) -> error.
fun_194(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 194};
fun_194(_) -> error.
'Fun195'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 195};
'Fun195'(_) -> error.
fun_195(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 195};
fun_195(_) -> error.
'Fun196'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 196};
'Fun196'(_) -> error.
fun_196(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 196};
fun_196(_) -> error.
'Fun197'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 197};
'Fun197'(_) -> error.
fun_197(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 197};
fun_197(_) -> error.
'Fun198'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 198};
'Fun198'(_) -> error.
fun_198(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 198};
fun_198(_) -> error.
'Fun199'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 199};
'Fun199'(_) -> error.
fun_199(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 199};
fun_199(_) -> error.
'Fun200'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 200};
'Fun200'(_) -> error.
fun_200(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 200};
fun_200(_) -> error.
