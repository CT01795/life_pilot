from sqlalchemy.orm import Session
import logging
import sys
from datetime import datetime, timezone
from sqlalchemy import text
from fastapi import APIRouter, Body, HTTPException
from config import engine, SessionLocal

from business_plan.model_plan_template import create_plan_template_model
from business_plan.model_business_plan import create_business_plan_model
from business_plan.model_plan_sections import create_plan_sections_model
from business_plan.model_plan_answer import create_plan_answer_model
from business_plan.model_plan_questions import create_plan_questions_model
from utils_service.utils import model_to_dict

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

router = APIRouter()
@router.post(
      "/business_plan/fetch_templates"
      , summary="取得模板清單"
      , description="""取得模板清單, 參數
        {'table_name': table_name}""")
def route_fetch_templates(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    print(table_name)
    db: Session = SessionLocal()
    try:
      print("try")
      PlanTemplateModel = create_plan_template_model(table_name)
      query = db.query(PlanTemplateModel).filter(PlanTemplateModel.is_valid == True).order_by(PlanTemplateModel.created_at)
      planList = query.all()
      if not planList:
        raise HTTPException(status_code=404, detail="fetch_templates plan not found")
      return [model_to_dict(plan) for plan in planList]
    finally:
      db.close()

@router.post(
      "/business_plan/create_plan_from_template"
      , summary="新增計畫"
      , description="""新增計畫, 參數
        { 'table_name': table_name
        , 'user': user
        , 'planId': planId
        , 'title': title
        , 'templateId': templateId,}""")   
def route_create_plan_from_template(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    user = payload.get("user")
    planId = payload.get("planId")
    title = payload.get("title")
    templateId = payload.get("templateId")
    db: Session = SessionLocal()
    try:
      BusinessPlanModel = create_business_plan_model(table_name)
      query = db.query(BusinessPlanModel).filter(BusinessPlanModel.created_by == user).filter(BusinessPlanModel.title == title)
      plan = query.first()
      if plan:
        if not plan.is_valid:
          setattr(plan, 'is_valid', True)
          db.commit()
        else:
          raise HTTPException(status_code=400, detail='Plan name already exists');
      else:
        plan_data = {
          'id': planId,
          'title': title,
          'template_id': templateId,
          'created_by': user,
          'created_at': datetime.now(timezone.utc),
          'is_valid': True,
        }
        plan = BusinessPlanModel(**plan_data)
        db.add(plan)
        db.commit()
      return model_to_dict(plan)
    finally:
      db.close()

@router.post(
      "/business_plan/get_sections_from_template"
      , summary="取得模板sections"
      , description="""取得模板sections, 參數
        { 'table_name': table_name
        , 'templateId': templateId}""")   
def route_get_sections_from_template(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    templateId = payload.get("templateId")
    db: Session = SessionLocal()
    try:
      SectionTemplateModel = create_plan_sections_model(table_name)
      query = db.query(SectionTemplateModel).filter(SectionTemplateModel.plan_id == templateId).order_by(SectionTemplateModel.sort_order)
      sectionList = query.all()
      if not sectionList:
        raise HTTPException(status_code=404, detail="Sections not found")
      return [model_to_dict(section) for section in sectionList]
    finally:
      db.close()

@router.post(
      "/business_plan/insert_plan_sections"
      , summary="新增計畫sections"
      , description="""新增計畫sections, 參數
        { 'table_name': table_name
        , 'id': id
        , 'plan_id': plan_id
        , 'title': title
        , 'sort_order': sort_order}""")   
def route_insert_plan_sections(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    id = payload.get("id")
    plan_id = payload.get("plan_id")
    title = payload.get("title")
    sort_order = payload.get("sort_order")
    db: Session = SessionLocal()
    try:
      PlanSectionModel = create_plan_sections_model(table_name)
      
      section_data = {
        'id': id,
        'plan_id': plan_id,
        'title': title,
        'sort_order': sort_order
      }
      section = PlanSectionModel(**section_data)
      db.add(section)
      db.commit()
      return model_to_dict(section)
    finally:
      db.close()

@router.post(
      "/business_plan/get_questions_from_template"
      , summary="取得模板questions"
      , description="""取得模板questions, 參數
        { 'table_name': table_name
        , 'section_id': section_id}""")   
def route_get_questions_from_template(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    section_id = payload.get("section_id")
    db: Session = SessionLocal()
    try:
      QuestionTemplateModel = create_plan_questions_model(table_name)
      query = db.query(QuestionTemplateModel).filter(QuestionTemplateModel.section_id == section_id).order_by(QuestionTemplateModel.sort_order)
      questionList = query.all()
      if not questionList:
        raise HTTPException(status_code=404, detail="Questions not found")
      return [model_to_dict(question) for question in questionList]
    finally:
      db.close()

@router.post(
      "/business_plan/insert_plan_questions"
      , summary="新增計畫questions"
      , description="""新增計畫questions, 參數
        { 'table_name': table_name
        , 'id': id
        , 'section_id': section_id
        , 'prompt': prompt
        , 'sort_order': sort_order}""")   
def route_insert_plan_questions(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    id = payload.get("id")
    section_id = payload.get("section_id")
    prompt = payload.get("prompt")
    sort_order = payload.get("sort_order")
    db: Session = SessionLocal()
    try:
      PlanQuestionModel = create_plan_questions_model(table_name)

      question_data = {
        'id': id,
        'section_id': section_id,
        'prompt': prompt,
        'sort_order': sort_order
      }
      question = PlanQuestionModel(**question_data)
      print(question_data)
      db.add(question)
      db.commit()
      return model_to_dict(question)
    finally:
      db.close()

@router.post(
      "/business_plan/update_plan_title"
      , summary="更新計劃名稱"
      , description="""更新計劃名稱, 參數
        { 'table_name': table_name
        , 'planId': planId
        , 'title': title,}""")     
def route_update_plan_title(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    planId = payload.get("planId")
    title = payload.get("title")
    
    db: Session = SessionLocal()
    try:
      BusinessPlanModel = create_business_plan_model(table_name)
      query = db.query(BusinessPlanModel).filter(BusinessPlanModel.id == planId)
      plan = query.first()
      if not plan:
          raise Exception("plan not found")
      # 更新傳入欄位
      setattr(plan, 'title', title)
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/business_plan/update_answer"
      , summary="更新答案"
      , description="""更新答案, 參數
        { 'table_name': table_name
        , 'planId': planId
        , 'sectionId': sectionId
        , 'questionId': questionId
        , 'answer': answer,}""")     
def route_update_answer(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    planId = payload.get("planId")
    sectionId = payload.get("sectionId")
    questionId = payload.get("questionId")
    answerText = payload.get("answer") or ""

    db: Session = SessionLocal()
    try:
      PlanAnswerModel = create_plan_answer_model(table_name)
      query = db.query(PlanAnswerModel).filter(PlanAnswerModel.plan_id == planId).filter(PlanAnswerModel.section_id == sectionId).filter(PlanAnswerModel.question_id == questionId)
      answer = query.first()
      if not answer:
        answer_data = {
          'plan_id': planId,
          'section_id': sectionId,
          'question_id': questionId,
          'answer': answerText,
          'updated_at': datetime.now(timezone.utc),
        }
        answer = PlanAnswerModel(**answer_data)
        db.add(answer)
      else: # 更新傳入欄位
        setattr(answer, 'answer', answerText)
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/business_plan/fetch_plans"
      , summary="取得計畫清單"
      , description="""取得計畫清單, 參數
        { 'table_name': table_name
        , 'user': user,}""")
def route_fetch_plans(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    user = payload.get("user")
    db: Session = SessionLocal()
    try:
      BusinessPlanModel = create_business_plan_model(table_name)
      query = db.query(BusinessPlanModel).filter(BusinessPlanModel.created_by == user).order_by(BusinessPlanModel.created_at)
      planList = query.all()
      if not planList:
        raise HTTPException(status_code=404, detail="fetch_plans plan not found")
      return [model_to_dict(plan) for plan in planList]
    finally:
      db.close()

@router.post(
    "/business_plan/fetch_plan_detail", 
    summary="取得計劃詳情", 
    description="""取得計劃詳情, 參數
      {'p_plan_id': p_plan_id,}""")   
def route_fetch_plan_detail(payload: dict = Body(...)):
    p_plan_id = payload.get("p_plan_id")
    with engine.begin() as conn:
        result = conn.execute(
            text("SELECT get_business_plan_detail(:p_plan_id)"),
            {
                "p_plan_id": p_plan_id
            }
        )
    row = result.fetchone()
    return row[0]  # 🔥 直接回 json