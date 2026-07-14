from sqlalchemy.orm import Session
import logging
import sys
from fastapi import APIRouter, Body
from config import SessionLocal

from game.model_game import create_game_grammar_user_model, create_game_list_model, create_game_translation_synonyms_model, create_game_user_model
from utils_service.utils import model_to_dict, route_fetch_data_by_rpc, route_insert

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

router = APIRouter()
@router.post(
      "/game/insert_game_user"
      , summary="新增使用者遊戲紀錄"
      , description="""新增使用者遊戲紀錄, 參數
        {'table_name': tableName,
         'data': data,}""")   
def route_insert_game_user(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    GameUserModel = create_game_user_model(table_name)
    return route_insert({"model": GameUserModel,"data":payload.get("data")})

@router.post(
      "/game/insert_game_grammar_user"
      , summary="新增grammar遊戲紀錄"
      , description="""新增grammar遊戲紀錄, 參數
        {'table_name': tableName,
         'data': data,}""")   
def route_insert_game_grammar_user(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    GameGrammarUserModel = create_game_grammar_user_model(table_name)
    return route_insert({"model": GameGrammarUserModel,"data":payload.get("data")})

@router.post(
      "/game/insert_game_sentence_user"
      , summary="新增sentence遊戲紀錄"
      , description="""新增sentence遊戲紀錄, 參數
        {'table_name': tableName,
         'data': data,}""")   
def route_insert_game_sentence_user(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    GameSentenceUserModel = create_game_grammar_user_model(table_name)
    return route_insert({"model": GameSentenceUserModel,"data":payload.get("data")})

@router.post(
      "/game/insert_game_speaking_user"
      , summary="新增speaking遊戲紀錄"
      , description="""新增speaking遊戲紀錄, 參數
        {'table_name': tableName,
         'data': data,}""")   
def route_insert_game_speaking_user(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    GameSpeakingUserModel = create_game_grammar_user_model(table_name)
    return route_insert({"model": GameSpeakingUserModel,"data":payload.get("data")})

@router.post(
      "/game/insert_game_translation_user"
      , summary="新增translation遊戲紀錄"
      , description="""新增translation遊戲紀錄, 參數
        {'table_name': tableName,
         'data': data,}""")   
def route_insert_game_translation_user(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    GameTranslationUserModel = create_game_grammar_user_model(table_name)
    return route_insert({"model": GameTranslationUserModel,"data":payload.get("data")})

@router.post(
      "/game/insert_game_word_search_user"
      , summary="新增word search遊戲紀錄"
      , description="""新增word search遊戲紀錄, 參數
        {'table_name': tableName,
         'data': data,}""")   
def route_insert_game_word_search_user(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    GameWordSearchUserModel = create_game_grammar_user_model(table_name)
    return route_insert({"model": GameWordSearchUserModel,"data":payload.get("data")})

@router.post(
      "/game/select_game_list"
      , summary="查詢遊戲清單"
      , description="""查詢遊戲清單, 參數
        {'table_name': tableName,}""")     
def route_select_game_list(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    db: Session = SessionLocal()
    try:
      GameListModel = create_game_list_model(table_name)
      query = db.query(
         GameListModel).order_by(
         GameListModel.game_type, 
         GameListModel.game_name, 
         GameListModel.level)
      gameList = query.all()
      if not gameList:
        return []
      return [model_to_dict(game) for game in gameList]

    finally:
      db.close()

@router.post(
      "/game/select_translation_synonyms"
      , summary="查詢translation遊戲synonyms"
      , description="""查詢translation遊戲synonyms, 參數
        {'table_name': tableName,}""")     
def route_select_translation_synonyms(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    db: Session = SessionLocal()
    try:
      TranslationSynonymsModel = create_game_translation_synonyms_model(table_name)
      query = db.query(TranslationSynonymsModel)
      translationSynonymsList = query.all()
      if not translationSynonymsList:
        return []
      return [model_to_dict(translationSynonyms) for translationSynonyms in translationSynonymsList]

    finally:
      db.close()

@router.post(
      "/game/fetch_user_progress"
      , summary="取得使用者紀錄"
      , description="""取得使用者紀錄,
          {'p_name': p_name,
           'p_game_type': p_game_type,
           'p_game_name': p_game_name,}""")     
def route_fetch_user_progress(payload: dict = Body(...)):
    return route_fetch_data_by_rpc(
        """
        SELECT row_to_json(t)
        FROM fetch_user_progress(
            :p_name,
            :p_game_type,
            :p_game_name
        ) t
        """,
        payload
    )

@router.post(
      "/game/get_grammar_question"
      , summary="取得grammar題目"
      , description="""取得grammar題目,
          {'user_name': user_name,
           'p_level': p_level,}""")     
def route_get_grammar_question(payload: dict = Body(...)):
    return route_fetch_data_by_rpc(
        """
        SELECT row_to_json(t)
        FROM get_grammar_question(
            :user_name,
            :p_level
        ) t
        """,
        payload
    )

@router.post(
      "/game/get_sentence_question"
      , summary="取得sentence題目"
      , description="""取得sentence題目,
          {'user_name': user_name,
           'p_level': p_level,}""")     
def route_get_sentence_question(payload: dict = Body(...)):
    return route_fetch_data_by_rpc(
        """
        SELECT row_to_json(t)
        FROM get_sentence_question(
            :user_name,
            :p_level
        ) t
        """,
        payload
    )

@router.post(
      "/game/get_speaking_question"
      , summary="取得speaking題目"
      , description="""取得speaking題目,
          {'user_name': user_name,
           'p_level': p_level,}""")     
def route_get_speaking_question(payload: dict = Body(...)):
    return route_fetch_data_by_rpc(
        """
        SELECT row_to_json(t)
        FROM get_speaking_question(
            :user_name,
            :p_level
        ) t
        """,
        payload
    )

@router.post(
      "/game/get_social_with_options"
      , summary="取得social題目"
      , description="""取得social題目,
          {'user_name': user_name,
           'p_level': p_level,}""")     
def route_get_social_with_options(payload: dict = Body(...)):
    return route_fetch_data_by_rpc(
        """
        SELECT row_to_json(t)
        FROM get_social_with_options(
            :user_name,
            :p_level
        ) t
        """,
        payload
    )

@router.post(
      "/game/get_translation_with_options"
      , summary="取得translation題目"
      , description="""取得translation題目,
          {'user_name': user_name,
           'p_level': p_level,}""")     
def route_get_translation_with_options(payload: dict = Body(...)):
    return route_fetch_data_by_rpc(
        """
        SELECT row_to_json(t)
        FROM get_translation_with_options(
            :user_name,
            :p_level
        ) t
        """,
        payload
    )

@router.post(
      "/game/get_translationjp_with_options"
      , summary="取得translation JP題目"
      , description="""取得translation JP題目,
          {'user_name': user_name,
           'p_level': p_level,}""")     
def route_get_translationjp_with_options(payload: dict = Body(...)):
    return route_fetch_data_by_rpc(
        """
        SELECT row_to_json(t)
        FROM get_translationjp_with_options(
            :user_name,
            :p_level
        ) t
        """,
        payload
    )

@router.post(
      "/game/get_translationkr_with_options"
      , summary="取得translation KR題目"
      , description="""取得translation KR題目,
          {'user_name': user_name,
           'p_level': p_level,}""")     
def route_get_translationkr_with_options(payload: dict = Body(...)):
    return route_fetch_data_by_rpc(
        """
        SELECT row_to_json(t)
        FROM get_translationkr_with_options(
            :user_name,
            :p_level
        ) t
        """,
        payload
    )

@router.post(
      "/game/get_next_word_question"
      , summary="取得Word Search題目"
      , description="""取得Word Search題目,
          {'user_name': user_name,
           'p_level': p_level,}""")     
def route_get_next_word_question(payload: dict = Body(...)):
    return route_fetch_data_by_rpc(
        """
        SELECT row_to_json(t)
        FROM get_next_word_question(
            :user_name,
            :p_level
        ) t
        """,
        payload
    )