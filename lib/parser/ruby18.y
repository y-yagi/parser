class Parser::Ruby18

token kCLASS kMODULE kDEF kUNDEF kBEGIN kRESCUE kENSURE kEND kIF kUNLESS
      kTHEN kELSIF kELSE kCASE kWHEN kWHILE kUNTIL kFOR kBREAK kNEXT
      kREDO kRETRY kIN kDO kDO_COND kDO_BLOCK kRETURN kYIELD kSUPER
      kSELF kNIL kTRUE kFALSE kAND kOR kNOT kIF_MOD kUNLESS_MOD kWHILE_MOD
      kUNTIL_MOD kRESCUE_MOD kALIAS kDEFINED klBEGIN klEND k__LINE__
      k__FILE__ tIDENTIFIER tFID tGVAR tIVAR tCONSTANT tCVAR tNTH_REF
      tBACK_REF tSTRING_CONTENT tINTEGER tFLOAT tREGEXP_END tUPLUS
      tUMINUS tUMINUS_NUM tPOW tCMP tEQ tEQQ tNEQ tGEQ tLEQ tANDOP
      tOROP tMATCH tNMATCH tDOT tDOT2 tDOT3 tAREF tASET tLSHFT tRSHFT
      tCOLON2 tCOLON3 tOP_ASGN tASSOC tLPAREN tLPAREN2 tRPAREN tLPAREN_ARG
      tLBRACK tLBRACK2 tRBRACK tLBRACE tLBRACE_ARG tSTAR tSTAR2 tAMPER tAMPER2
      tTILDE tPERCENT tDIVIDE tPLUS tMINUS tLT tGT tPIPE tBANG tCARET
      tLCURLY tRCURLY tBACK_REF2 tSYMBEG tSTRING_BEG tXSTRING_BEG tREGEXP_BEG
      tWORDS_BEG tQWORDS_BEG tSTRING_DBEG tSTRING_DVAR tSTRING_END tSTRING
      tSYMBOL tREGEXP_OPT tNL tEH tCOLON tCOMMA tSPACE tSEMI

prechigh
  right    tBANG tTILDE tUPLUS
  right    tPOW
  right    tUMINUS_NUM tUMINUS
  left     tSTAR2 tDIVIDE tPERCENT
  left     tPLUS tMINUS
  left     tLSHFT tRSHFT
  left     tAMPER2
  left     tPIPE tCARET
  left     tGT tGEQ tLT tLEQ
  nonassoc tCMP tEQ tEQQ tNEQ tMATCH tNMATCH
  left     tANDOP
  left     tOROP
  nonassoc tDOT2 tDOT3
  right    tEH tCOLON
  left     kRESCUE_MOD
  right    tEQL tOP_ASGN
  nonassoc kDEFINED
  right    kNOT
  left     kOR kAND
  nonassoc kIF_MOD kUNLESS_MOD kWHILE_MOD kUNTIL_MOD
  nonassoc tLBRACE_ARG
  nonassoc tLOWEST
preclow

rule

         program: compstmt
                    {
                      result = val[0]
                    }

        bodystmt: compstmt opt_rescue opt_else opt_ensure
                    {
                      rescue_, t_rescue = val[1]
                      else_,   t_else   = val[2]
                      ensure_, t_ensure = val[3]

                      result = @builder.begin(val[0],
                                  rescue_, t_rescue,
                                  else_,   t_else,
                                  ensure_, t_ensure)
                    }

        compstmt: stmts opt_terms
                    {
                      result = @builder.compstmt(val[0])
                    }

           stmts: none
                    {
                      result = []
                    }
                | stmt
                    {
                      result = [ val[0] ]
                    }
                | error stmt
                    {
                      result = [ val[1] ]
                    }
                | stmts terms stmt
                    {
                      result = val[0] << val[2]
                    }

            stmt: kALIAS fitem
                    {
                      @lexer.state = :expr_fname
                    }
                    fitem
                    {
                      result = @builder.alias(val[0], val[1], val[3])
                    }
                | kALIAS tGVAR tGVAR
                    {
                      result = @builder.alias(val[0],
                                  @builder.gvar(val[1]),
                                  @builder.gvar(val[2]))
                    }
                | kALIAS tGVAR tBACK_REF
                    {
                      result = @builder.alias(val[0],
                                  @builder.gvar(val[1]),
                                  @builder.back_ref(val[2]))
                    }
                | kALIAS tGVAR tNTH_REF
                    {
                      syntax_error(:nth_ref_alias, val[2])
                    }
                | kUNDEF undef_list
                    {
                      result = @builder.undef_method(val[0], val[1])
                    }
                | stmt kIF_MOD expr_value
                    {
                      result = new_if val[2], val[0], nil
                    }
                | stmt kUNLESS_MOD expr_value
                    {
                      result = new_if val[2], nil, val[0]
                    }
                | stmt kWHILE_MOD expr_value
                    {
                      result = new_while val[0], val[2], true
                    }
                | stmt kUNTIL_MOD expr_value
                    {
                      result = new_until val[0], val[2], true
                    }
                | stmt kRESCUE_MOD stmt
                    {
                      result = s(:rescue, val[0], new_resbody(s(:array), val[2]))
                    }
                | klBEGIN
                    {
                      if in_def?
                        syntax_error(:begin_in_method, val[0])
                      end

                      @static_env.extend
                    }
                    tLCURLY compstmt tRCURLY
                    {
                      result = new_iter s(:preexe), nil, val[3] # TODO: add test?
                      result = nil # TODO: since it isn't supposed to go in the AST
                    }
                | klEND tLCURLY compstmt tRCURLY
                    {
                      if in_def?
                        syntax_error(:end_in_method, val[0])
                      end

                      result = new_iter s(:postexe), nil, val[2]
                    }
                | lhs tEQL command_call
                    {
                      result = @builder.assign(val[0], val[1], val[2])
                    }
                | mlhs tEQL command_call
                    {
                      result = new_masgn val[0], val[2], :wrap
                    }
                | var_lhs tOP_ASGN command_call
                    {
                      result = @builder.op_assign(val[0], val[1], val[2])
                    }
                | primary_value tLBRACK2 aref_args tRBRACK tOP_ASGN command_call
                    {
                      result = s(:op_asgn1, val[0], val[2], val[4].to_sym, val[5])
                    }
                | primary_value tDOT tIDENTIFIER tOP_ASGN command_call
                    {
                      result = s(:op_asgn, val[0], val[4], val[2], val[3])
                    }
                | primary_value tDOT tCONSTANT tOP_ASGN command_call
                    {
                      result = s(:op_asgn, val[0], val[4], val[2], val[3])
                    }
                | primary_value tCOLON2 tIDENTIFIER tOP_ASGN command_call
                    {
                      result = s(:op_asgn, val[0], val[4], val[2], val[3])
                    }
                | backref tOP_ASGN command_call
                    {
                      @builder.operator_assign(*val)
                    }
                | lhs tEQL mrhs
                    {
                      result = @builder.assign(val[0], val[1],
                                  @builder.array(nil, val[2], nil))
                    }
                | mlhs tEQL arg_value
                    {
                      result = @builder.multi_assign(val[0], val[1], val[2])
                    }
                | mlhs tEQL mrhs
                    {
                      result = @builder.multi_assign(val[0], val[1],
                                  @builder.array(nil, val[2], nil))
                    }
                | expr

            expr: command_call
                | expr kAND expr
                    {
                      result = logop(:and, val[0], val[2])
                    }
                | expr kOR expr
                    {
                      result = logop(:or, val[0], val[2])
                    }
                | kNOT expr
                    {
                      result = @builder.not_op(val[0], val[1])
                    }
                | tBANG command_call
                    {
                      result = @builder.not_op(val[0], val[1])
                    }
                | arg

      expr_value: expr
                    {
                      result = value_expr(val[0])
                    }

    command_call: command
                | block_command
                | kRETURN call_args
                    {
                      result = @builder.keyword_cmd(:return, val[0], val[1])
                    }
                | kBREAK call_args
                    {
                      result = @builder.keyword_cmd(:break, val[0], val[1])
                    }
                | kNEXT call_args
                    {
                      result = @builder.keyword_cmd(:next, val[0], val[1])
                    }

   block_command: block_call
                | block_call tDOT operation2 command_args
                    {
                      result = new_call val[0], val[2], val[3]
                    }
                | block_call tCOLON2 operation2 command_args
                    {
                      result = new_call val[0], val[2], val[3]
                    }

 cmd_brace_block: tLBRACE_ARG
                    {
                      @static_env.extend_dynamic
                    }
                    opt_block_var compstmt tRCURLY
                    {
                      result = new_iter nil, val[2], val[3]

                      @static_env.unextend
                    }

         command: operation command_args =tLOWEST
                    {
                      result = new_call nil, val[0].to_sym, val[1]
                    }
                | operation command_args cmd_brace_block
                    {
                      result = new_call nil, val[0].to_sym, val[1]

                      if val[2] then
                        block_dup_check result, val[2]

                        result, operation = val[2], result
                        result.insert 1, operation
                      end
                    }
                | primary_value tDOT operation2 command_args =tLOWEST
                    {
                      result = new_call val[0], val[2].to_sym, val[3]
                    }
                | primary_value tDOT operation2 command_args cmd_brace_block
                    {
                      result = new_call val[0], val[2].to_sym, val[3]
                      raise "no2"

                      if val[4] then
                        block_dup_check result, val[4]

                        val[2] << result
                        result = val[2]
                      end
                    }
                | primary_value tCOLON2 operation2 command_args =tLOWEST
                    {
                      result = new_call val[0], val[2].to_sym, val[3]
                    }
                | primary_value tCOLON2 operation2 command_args cmd_brace_block
                    {
                      result = new_call val[0], val[2].to_sym, val[3]
                      raise "no3"

                      if val[4] then
                        block_dup_check result, val[4]

                        val[2] << result
                        result = val[2]
                      end
                    }
                | kSUPER command_args
                    {
                      result = new_super val[1]
                    }
                | kYIELD command_args
                    {
                      result = new_yield val[1]
                    }

            mlhs: mlhs_basic
                    {
                      result = @builder.multi_lhs(nil, val[0], nil)
                    }
                | tLPAREN mlhs_entry tRPAREN
                    {
                      result = @builder.paren(val[0], val[1], val[2])
                    }

      mlhs_entry: mlhs_basic
                    {
                      result = @builder.multi_lhs(nil, val[0], nil)
                    }
                | tLPAREN mlhs_entry tRPAREN
                    {
                      result = @builder.multi_lhs(val[0], val[1], val[2])
                    }

      mlhs_basic: mlhs_head
                    {
                      result = val[0]
                    }
                | mlhs_head mlhs_item
                    {
                      result = val[0] << val[1]
                    }
                | mlhs_head tSTAR mlhs_node
                    {
                      result = val[0] << @builder.splat(val[1], val[2])
                    }
                | mlhs_head tSTAR
                    {
                      result = val[0] << @builder.splat(val[1])
                    }
                | tSTAR mlhs_node
                    {
                      result = [ @builder.splat(val[0], val[1]) ]
                    }
                | tSTAR
                    {
                      result = [ @builder.splat(val[0]) ]
                    }

       mlhs_item: mlhs_node
                | tLPAREN mlhs_entry tRPAREN
                    {
                      result = @builder.paren(val[0], val[1], val[2])
                    }

       mlhs_head: mlhs_item tCOMMA
                    {
                      result = [ val[0] ]
                    }
                | mlhs_head mlhs_item tCOMMA
                    {
                      result = val[0] << val[1]
                    }

       mlhs_node: variable
                    {
                      result = @builder.assignable(val[0])
                    }
                | primary_value tLBRACK2 aref_args tRBRACK
                    {
                      result = @builder.index_asgn(val[0], val[1], val[2], val[3])
                    }
                | primary_value tDOT tIDENTIFIER
                    {
                      result = @builder.attr_asgn(val[0], val[1], val[2])
                    }
                | primary_value tCOLON2 tIDENTIFIER
                    {
                      result = @builder.attr_asgn(val[0], val[1], val[2])
                    }
                | primary_value tDOT tCONSTANT
                    {
                      result = @builder.attr_asgn(val[0], val[1], val[2])
                    }
                | primary_value tCOLON2 tCONSTANT
                    {
                      if in_def?
                        syntax_error :dynamic_const, val[2]
                      end

                      result = @builder.assignable(
                                  @builder.const_fetch(val[0], val[1], val[2]))
                    }
                | tCOLON3 tCONSTANT
                    {
                      if in_def?
                        syntax_error :dynamic_const, val[1]
                      end

                      result = @builder.assignable(
                                  @builder.const_global(val[0], val[1]))
                    }
                | backref
                    {
                      result = @builder.assignable(val[0])
                    }

             lhs: variable
                    {
                      result = @builder.assignable(val[0])
                    }
                | primary_value tLBRACK2 aref_args tRBRACK
                    {
                      result = @builder.index_asgn(val[0], val[1], val[2], val[3])
                    }
                | primary_value tDOT tIDENTIFIER
                    {
                      result = @builder.attr_asgn(val[0], val[1], val[2])
                    }
                | primary_value tCOLON2 tIDENTIFIER
                    {
                      result = @builder.attr_asgn(val[0], val[1], val[2])
                    }
                | primary_value tDOT tCONSTANT
                    {
                      result = @builder.attr_asgn(val[0], val[1], val[2])
                    }
                | primary_value tCOLON2 tCONSTANT
                    {
                      if in_def?
                        syntax_error :dynamic_const, val[2]
                      end

                      result = @builder.assignable(
                                  @builder.const_fetch(val[0], val[1], val[2]))
                    }
                | tCOLON3 tCONSTANT
                    {
                      if in_def?
                        syntax_error :dynamic_const, val[1]
                      end

                      result = @builder.assignable(
                                  @builder.const_global(val[0], val[1]))
                    }
                | backref
                    {
                      result = @builder.assignable(val[0])
                    }

           cname: tIDENTIFIER
                    {
                      syntax_error(:module_name_const, val[0])
                    }
                | tCONSTANT

           cpath: tCOLON3 cname
                    {
                      result = @builder.const_global(val[0], val[1])
                    }
                | cname
                    {
                      result = @builder.const(val[0])
                    }
                | primary_value tCOLON2 cname
                    {
                      result = @builder.const_fetch(val[0], val[1], val[2])
                    }

           fname: tIDENTIFIER | tCONSTANT | tFID
                | op
                | reswords

            fsym: fname
                    {
                      result = @builder.symbol(val[0])
                    }
                | symbol

           fitem: fsym
                | dsym

      undef_list: fitem
                    {
                      result = [ val[0] ]
                    }
                | undef_list tCOMMA
                    {
                      @lexer.state = :expr_fname
                    }
                    fitem
                    {
                      result = val[0] << val[3]
                    }

              op: tPIPE    | tCARET     | tAMPER2 | tCMP   | tEQ     | tEQQ
                | tMATCH   | tGT        | tGEQ    | tLT    | tLEQ    | tLSHFT
                | tRSHFT   | tPLUS      | tMINUS  | tSTAR2 | tSTAR   | tDIVIDE
                | tPERCENT | tPOW       | tTILDE  | tUPLUS | tUMINUS | tAREF
                | tASET    | tBACK_REF2

        reswords: k__LINE__ | k__FILE__   | klBEGIN | klEND  | kALIAS  | kAND
                | kBEGIN    | kBREAK      | kCASE   | kCLASS | kDEF    | kDEFINED
                | kDO       | kELSE       | kELSIF  | kEND   | kENSURE | kFALSE
                | kFOR      | kIN         | kMODULE | kNEXT  | kNIL    | kNOT
                | kOR       | kREDO       | kRESCUE | kRETRY | kRETURN | kSELF
                | kSUPER    | kTHEN       | kTRUE   | kUNDEF | kWHEN   | kYIELD
                | kIF       | kUNLESS     | kWHILE  | kUNTIL

             arg: lhs tEQL arg
                    {
                      result = @builder.assign(val[0], val[1], val[2])
                    }
                | lhs tEQL arg kRESCUE_MOD arg
                    {
                      result = node_assign val[0], s(:rescue, val[2], new_resbody(s(:array), val[4]))
                      # result.line = val[0].line
                    }
                | var_lhs tOP_ASGN arg
                    {
                      result = @builder.op_assign(val[0], val[1], val[2])
                    }
                | primary_value tLBRACK2 aref_args tRBRACK tOP_ASGN arg
                    {
                      result = @builder.op_assign(
                                  @builder.index(
                                    val[0], val[1], val[2], val[3]),
                                  val[4], val[5])
                    }
                | primary_value tDOT tIDENTIFIER tOP_ASGN arg
                    {
                      result = @builder.op_assign(
                                  @builder.call_method(
                                    val[0], val[1], val[2]),
                                  val[3], val[4])
                    }
                | primary_value tDOT tCONSTANT tOP_ASGN arg
                    { # TODO: Unused with the Ragel lexer. Remove?
                      result = @builder.op_assign(
                                  @builder.call_method(
                                    val[0], val[1], val[2]),
                                  val[3], val[4])
                    }
                | primary_value tCOLON2 tIDENTIFIER tOP_ASGN arg
                    {
                      result = @builder.op_assign(
                                  @builder.call_method(
                                    val[0], val[1], val[2]),
                                  val[3], val[4])
                    }
                | primary_value tCOLON2 tCONSTANT tOP_ASGN arg
                    {
                      syntax_error :dynamic_const, val[2], [ val[3] ]
                    }
                | tCOLON3 tCONSTANT tOP_ASGN arg
                    {
                      syntax_error :dynamic_const, val[1], [ val[2] ]
                    }
                | backref tOP_ASGN arg
                    {
                      result = @builder.op_assign(val[0], val[1], val[2])
                    }
                | arg tDOT2 arg
                    {
                      result = @builder.range_inclusive(val[0], val[1], val[2])
                    }
                | arg tDOT3 arg
                    {
                      result = @builder.range_exclusive(val[0], val[1], val[2])
                    }
                | arg tPLUS arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tMINUS arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tSTAR2 arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tDIVIDE arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tPERCENT arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tPOW arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | tUMINUS_NUM tINTEGER tPOW arg
                    {
                      result = @builder.unary_op(val[0],
                                  @builder.binary_op(
                                    @builder.integer(val[1]),
                                      val[2], val[3]))
                    }
                | tUMINUS_NUM tFLOAT tPOW arg
                    {
                      result = @builder.unary_op(val[0],
                                  @builder.binary_op(
                                    @builder.float(val[1]),
                                      val[2], val[3]))
                    }
                | tUPLUS arg
                    {
                      result = @builder.unary_op(val[0], val[1])
                    }
                | tUMINUS arg
                    {
                      result = @builder.unary_op(val[0], val[1])
                    }
                | arg tPIPE arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tCARET arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tAMPER2 arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tCMP arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tGT arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tGEQ arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tLT arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tLEQ arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tEQ arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tEQQ arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tNEQ arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tMATCH arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tNMATCH arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | tBANG arg
                    {
                      result = @builder.not_op(val[0], val[1])
                    }
                | tTILDE arg
                    {
                      result = @builder.unary_op(val[0], val[1])
                    }
                | arg tLSHFT arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tRSHFT arg
                    {
                      result = @builder.binary_op(val[0], val[1], val[2])
                    }
                | arg tANDOP arg
                    {
                      result = logop(:and, val[0], val[2])
                    }
                | arg tOROP arg
                    {
                      result = logop(:or, val[0], val[2])
                    }
                | kDEFINED opt_nl arg
                    {
                      result = @builder.keyword_cmd(:defined?, val[0], nil, [ val[2] ], nil)
                    }
                | arg tEH arg tCOLON arg
                    {
                      result = s(:if, val[0], val[2], val[4])
                    }
                | primary

       arg_value: arg
                    {
                      result = value_expr(val[0])
                    }

       aref_args: none
                | command opt_nl
                    {
                      warning 'parenthesize argument(s) for future version'
                      result = s(:array, val[0])
                    }
                | args trailer
                    {
                      result = val[0]
                    }
                | args tCOMMA tSTAR arg opt_nl
                    {
                      result = val[0] << @builder.splat(val[2], val[3])
                    }
                | assocs trailer
                    {
                      result = [ @builder.associate(nil, val[0], nil) ]
                    }
                | tSTAR arg opt_nl
                    {
                      result = [ @builder.splat(val[0], val[1]) ]
                    }

      paren_args: tLPAREN2 none tRPAREN
                    {
                      result = [ val[0], val[1], val[2] ]
                    }
                | tLPAREN2 call_args opt_nl tRPAREN
                    {
                      result = [ val[0], val[1], val[3] ]
                    }
                | tLPAREN2 block_call opt_nl tRPAREN
                    {
                      warning "parenthesize argument(s) for future version"
                      result = s(:array, val[1])
                    }
                | tLPAREN2 args tCOMMA block_call opt_nl tRPAREN
                    {
                      warning "parenthesize argument(s) for future version"
                      result = val[1].add val[3]
                    }

  opt_paren_args: none
                | paren_args

       call_args: command
                    {
                      warning "parenthesize argument(s) for future version"
                      result = s(:array, val[0])
                    }
                | args opt_block_arg
                    {
                      result = arg_blk_pass val[0], val[1]
                    }
                | args tCOMMA tSTAR arg_value opt_block_arg
                    {
                      result = arg_concat val[0], val[3]
                      result = arg_blk_pass result, val[4]
                    }
                | assocs opt_block_arg
                    {
                      result = s(:array, s(:hash, *val[0].values))
                      result = arg_blk_pass result, val[1]
                    }
                | assocs tCOMMA tSTAR arg_value opt_block_arg
                    {
                      result = arg_concat s(:array, s(:hash, *val[0].values)), val[3]
                      result = arg_blk_pass result, val[4]
                    }
                | args tCOMMA assocs opt_block_arg
                    {
                      result = val[0] << s(:hash, *val[2].values)
                      result = arg_blk_pass result, val[3]
                    }
                | args tCOMMA assocs tCOMMA tSTAR arg opt_block_arg
                    {
                      val[0] << s(:hash, *val[2].values)
                      result = arg_concat val[0], val[5]
                      result = arg_blk_pass result, val[6]
                    }
                | tSTAR arg_value opt_block_arg
                    {
                      result = arg_blk_pass s(:splat, val[1]), val[2]
                    }
                | block_arg

      call_args2: arg_value tCOMMA args opt_block_arg
                    {
                      args = list_prepend val[0], val[2]
                      result = arg_blk_pass args, val[3]
                    }
                | arg_value tCOMMA block_arg
                    {
                      result = arg_blk_pass val[0], val[2]
                    }
                | arg_value tCOMMA tSTAR arg_value opt_block_arg
                    {
                      result = arg_concat s(:array, val[0]), val[3]
                      result = arg_blk_pass result, val[4]
                    }
                | arg_value tCOMMA args tCOMMA tSTAR arg_value opt_block_arg
                    {
                      result = arg_concat s(:array, val[0], s(:hash, *val[2].values)), val[5]
                      result = arg_blk_pass result, val[6]
                    }
                | assocs opt_block_arg
                    {
                      result = s(:array, s(:hash, *val[0].values))
                      result = arg_blk_pass result, val[1]
                    }
                | assocs tCOMMA tSTAR arg_value opt_block_arg
                    {
                      result = s(:array, s(:hash, *val[0].values), val[3])
                      result = arg_blk_pass result, val[4]
                    }
                | arg_value tCOMMA assocs opt_block_arg
                    {
                      result = s(:array, val[0], s(:hash, *val[2].values))
                      result = arg_blk_pass result, val[3]
                    }
                | arg_value tCOMMA args tCOMMA assocs opt_block_arg
                    {
                      result = s(:array, val[0]).add_all(val[2]).add(s(:hash, *val[4].values))
                      result = arg_blk_pass result, val[5]
                    }
                | arg_value tCOMMA assocs tCOMMA tSTAR arg_value opt_block_arg
                    {
                      result = arg_concat s(:array, val[0]).add(s(:hash, *val[2].values)), val[5]
                      result = arg_blk_pass result, val[6]
                    }
                | arg_value tCOMMA args tCOMMA assocs tCOMMA tSTAR arg_value opt_block_arg
                    {
                      result = arg_concat s(:array, val[0]).add_all(val[2]).add(s(:hash, *val[4].values)), val[7]
                      result = arg_blk_pass result, val[8]
                    }
                | tSTAR arg_value opt_block_arg
                    {
                      result = arg_blk_pass s(:splat, val[1]), val[2]
                    }
                | block_arg

    command_args:   {
                      #result = lexer.cmdarg.stack.dup
                      #lexer.cmdarg.push true
                    }
                    open_args
                    {
                      #lexer.cmdarg.stack.replace val[0]
                      result = val[1]
                    }

       open_args: call_args
                | tLPAREN_ARG
                    {
                      lexer.state = :expr_endarg
                    }
                    tRPAREN
                    {
                      warning "don't put space before argument parentheses"
                      result = nil
                    }
                | tLPAREN_ARG call_args2
                    {
                      lexer.state = :expr_endarg
                    }
                    tRPAREN
                    {
                      warning "don't put space before argument parentheses"
                      result = val[1]
                    }

       block_arg: tAMPER arg_value
                    {
                      result = s(:block_pass, val[1])
                    }

   opt_block_arg: tCOMMA block_arg
                    {
                      result = val[1]
                    }
                | none

            args: arg_value
                    {
                      result = [ val[0] ]
                    }
                | args tCOMMA arg_value
                    {
                      result = val[0] << val[2]
                    }

            mrhs: args tCOMMA arg_value
                    {
                      result = val[0] << val[2]
                    }
                | args tCOMMA tSTAR arg_value
                    {
                      result = val[0] << @builder.splat(val[2], val[3])
                    }
                | tSTAR arg_value
                    {
                      result = [ @builder.splat(val[0], val[1]) ]
                    }

         primary: literal
                | strings
                | xstring
                | regexp
                | words
                | qwords
                | var_ref
                | backref
                | tFID
                    {
                      result = new_call nil, val[0].to_sym
                    }
                | kBEGIN bodystmt kEND
                    {
                      unless val[1] then
                        result = s(:nil)
                      else
                        result = s(:begin, val[1])
                      end
                    }
                | tLPAREN_ARG expr
                    {
                      lexer.state = :expr_endarg
                    }
                    opt_nl tRPAREN
                    {
                      warning "(...) interpreted as grouped expression"
                      result = val[1]
                    }
                | tLPAREN compstmt tRPAREN
                    {
                      result = val[1]
                      result.paren = true
                    }
                | primary_value tCOLON2 tCONSTANT
                    {
                      result = @builder.const_fetch(val[0], val[1], val[2])
                    }
                | tCOLON3 tCONSTANT
                    {
                      result = @builder.const_global(val[0], val[1])
                    }
                | primary_value tLBRACK2 aref_args tRBRACK
                    {
                      result = @builder.index(val[0], val[1], val[2], val[3])
                    }
                | tLBRACK aref_args tRBRACK
                    {
                      result = @builder.array(val[0], val[1], val[2])
                    }
                | tLBRACE assoc_list tRCURLY
                    {
                      result = @builder.associate(val[0], val[1], val[2])
                    }
                | kRETURN
                    {
                      result = @builder.keyword_cmd(:return, val[0])
                    }
                | kYIELD tLPAREN2 call_args tRPAREN
                    {
                      result = @builder.keyword_cmd(:yield, val[0], val[1], val[2], val[3])
                    }
                | kYIELD tLPAREN2 tRPAREN
                    {
                      result = @builder.keyword_cmd(:yield, val[0], val[1], nil, val[2])
                    }
                | kYIELD
                    {
                      result = @builder.keyword_cmd(:yield, val[0])
                    }
                | kDEFINED opt_nl tLPAREN2 expr tRPAREN
                    {
                      result = @builder.keyword_cmd(:defined?, val[0],
                                                    val[2], [ val[3] ], val[4])
                    }
                | operation brace_block
                    {
                      oper, iter = val[0], val[1]
                      call = new_call(nil, oper.to_sym)
                      iter.insert 1, call
                      result = iter
                      call.line = iter.line
                    }
                | method_call
                | method_call brace_block
                    {
                      call, iter = val[0], val[1]
                      block_dup_check call, iter

                      iter.insert 1, call
                      result = iter
                    }
                | kIF expr_value then compstmt if_tail kEND
                    {
                      result = new_if val[1], val[3], val[4]
                    }
                | kUNLESS expr_value then compstmt opt_else kEND
                    {
                      result = new_if val[1], val[4], val[3]
                    }
                | kWHILE
                    {
                      #lexer.cond.push true
                    }
                    expr_value do
                    {
                      #lexer.cond.pop
                    }
                    compstmt kEND
                    {
                      result = new_while val[5], val[2], true
                    }
                | kUNTIL
                    {
                      #lexer.cond.push true
                    }
                    expr_value do
                    {
                      #lexer.cond.pop
                    }
                    compstmt kEND
                    {
                      result = new_until val[5], val[2], true
                    }
                | kCASE expr_value opt_terms case_body kEND
                    {
                      result = new_case val[1], val[3]
                    }
                | kCASE            opt_terms case_body kEND
                    {
                      result = new_case nil, val[2]
                    }
                | kCASE opt_terms kELSE compstmt kEND # TODO: need a test
                    {
                      result = new_case nil, val[3]
                    }
                | kFOR for_var kIN
                    {
                      #lexer.cond.push true
                    }
                    expr_value do
                    {
                      #lexer.cond.pop
                    }
                    compstmt kEND
                    {
                      result = new_for val[4], val[1], val[7]
                    }
                | kCLASS cpath superclass
                    {
                      if in_def?
                        yyerror "class definition in method body"
                      end

                      @comments.push @lexer.clear_comments
                      @static_env.extend_static
                    }
                    bodystmt kEND
                    {
                      lt_t, superclass = val[2]
                      result = @builder.def_class(val[0], val[1],
                                                  lt_t, superclass,
                                                  val[4], val[5])

                      @static_env.unextend
                      @lexer.clear_comments
                    }
                | kCLASS tLSHFT expr term
                    {
                      result = @def_level
                      @def_level = 0

                      @static_env.extend_static
                    }
                    bodystmt kEND
                    {
                      result = @builder.def_sclass(val[0], val[1], val[2],
                                                   val[5], val[6])

                      @static_env.unextend
                      @lexer.clear_comments

                      @def_level = val[4]
                    }
                | kMODULE cpath
                    {
                      if in_def?
                        yyerror "module definition in method body"
                      end

                      @comments.push @lexer.clear_comments
                      @static_env.extend_static
                    }
                    bodystmt kEND
                    {
                      result = @builder.def_module(val[0], val[1],
                                                   val[3], val[4])

                      @static_env.unextend
                      @lexer.clear_comments
                    }
                | kDEF fname
                    {
                      @comments.push @lexer.clear_comments
                      @def_level += 1
                      @static_env.extend_static
                    }
                    f_arglist bodystmt kEND
                    {
                      result = @builder.def_method(val[0], val[1],
                                  val[3], val[4], val[5], @comments.pop)

                      @static_env.unextend
                      @def_level -= 1
                      @lexer.clear_comments
                    }
                | kDEF singleton dot_or_colon
                    {
                      @comments.push @lexer.clear_comments
                      @lexer.state = :expr_fname
                    }
                    fname
                    {
                      @def_level += 1
                      @static_env.extend_static
                    }
                    f_arglist bodystmt kEND
                    {
                      result = @builder.def_singleton(val[0], val[1], val[2],
                                  val[4], val[6], val[7], val[8], @comments.pop)

                      @static_env.unextend
                      @def_level -= 1
                      @lexer.clear_comments
                    }
                | kBREAK
                    {
                      result = @builder.keyword_cmd(:break, val[0])
                    }
                | kNEXT
                    {
                      result = @builder.keyword_cmd(:next, val[0])
                    }
                | kREDO
                    {
                      result = @builder.keyword_cmd(:redo, val[0])
                    }
                | kRETRY
                    {
                      result = @builder.keyword_cmd(:retry, val[0])
                    }

   primary_value: primary
                    {
                      result = value_expr(val[0])
                    }

            then: term
                | tCOLON
                | kTHEN
                | term kTHEN

              do: term
                | tCOLON
                | kDO_COND

         if_tail: opt_else
                | kELSIF expr_value then compstmt if_tail
                    {
                      result = s(:if, val[1], val[3], val[4])
                    }

        opt_else: none
                | kELSE compstmt
                    {
                      result = val[1]
                    }

         for_var: lhs
                | mlhs
                    {
                      val[0].delete_at 1 if val[0][1].nil? # HACK
                    }

       block_par: mlhs_item
                    {
                      result = s(:array, clean_mlhs(val[0]))
                    }
                | block_par tCOMMA mlhs_item
                    {
                      result = list_append val[0], clean_mlhs(val[2])
                    }

       block_var: block_par
                    {
                      result = block_var18 val[0], nil, nil
                    }
                | block_par tCOMMA
                    {
                      result = block_var18 val[0], nil, nil
                    }
                | block_par tCOMMA tAMPER lhs
                    {
                      result = block_var18 val[0], nil, val[3]
                    }
                | block_par tCOMMA tSTAR lhs tCOMMA tAMPER lhs
                    {
                      result = block_var18 val[0], val[3], val[6]
                    }
                | block_par tCOMMA tSTAR tCOMMA tAMPER lhs
                    {
                      result = block_var18 val[0], s(:splat), val[5]
                    }
                | block_par tCOMMA tSTAR lhs
                    {
                      result = block_var18 val[0], val[3], nil
                    }
                | block_par tCOMMA tSTAR
                    {
                      result = block_var18 val[0], s(:splat), nil
                    }
                | tSTAR lhs tCOMMA tAMPER lhs
                    {
                      result = block_var18 nil, val[1], val[4]
                    }
                | tSTAR tCOMMA tAMPER lhs
                    {
                      result = block_var18 nil, s(:splat), val[3]
                    }
                | tSTAR lhs
                    {
                      result = block_var18 nil, val[1], nil
                    }
                | tSTAR
                    {
                      result = block_var18 nil, s(:splat), nil
                    }
                | tAMPER lhs
                    {
                      result = block_var18 nil, nil, val[1]
                    }
                ;

   opt_block_var: none
                | tPIPE tPIPE
                    {
                      result = 0
                    }
                | tOROP
                    {
                      result = 0
                    }
                | tPIPE block_var tPIPE
                    {
                      result = val[1]
                    }

        do_block: kDO_BLOCK
                    {
                      @static_env.extend_dynamic
                    }
                    opt_block_var compstmt kEND
                    {
                      vars   = val[2]
                      body   = val[3]
                      result = new_iter nil, vars, body

                      @static_env.unextend
                    }

      block_call: command do_block
                    {
                      block_dup_check val[0], val[1]

                      result = val[1]
                      result.insert 1, val[0]
                    }
                | block_call tDOT operation2 opt_paren_args
                    {
                      result = new_call val[0], val[2], val[3]
                    }
                | block_call tCOLON2 operation2 opt_paren_args
                    {
                      result = new_call val[0], val[2], val[3]
                    }

     method_call: operation paren_args
                    {
                      lparen_t, args, rparen_t = val[1]
                      result = @builder.call_method(nil, nil, val[0],
                                  lparen_t, args, rparen_t)
                    }
                | primary_value tDOT operation2 opt_paren_args
                    {
                      lparen_t, args, rparen_t = val[3]
                      result = @builder.call_method(val[0], val[1], val[2],
                                  lparen_t, args, rparen_t)
                    }
                | primary_value tCOLON2 operation2 paren_args
                    {
                      lparen_t, args, rparen_t = val[3]
                      result = @builder.call_method(val[0], val[1], val[2],
                                  lparen_t, args, rparen_t)
                    }
                | primary_value tCOLON2 operation3
                    {
                      result = @builder.call_method(val[0], val[1], val[2])
                    }
                | kSUPER paren_args
                    {
                      result = new_super val[1]
                    }
                | kSUPER
                    {
                      result = s(:zsuper)
                    }

     brace_block: tLCURLY
                    {
                      @static_env.extend_dynamic
                    }
                    opt_block_var compstmt tRCURLY
                    {
                      result = new_iter nil, val[2], val[3]

                      @static_env.unextend
                    }
                | kDO
                    {
                      @static_env.extend_dynamic
                    }
                    opt_block_var compstmt kEND
                    {
                      result = new_iter nil, val[2], val[3]

                      @static_env.unextend
                    }

       case_body: kWHEN when_args then compstmt cases
                    {
                      result = new_when(val[2], val[4])
                      result << val[5] if val[5]
                    }

       when_args: args
                | args tCOMMA tSTAR arg_value
                    {
                      result = list_append val[0], s(:splat, val[3])
                    }
                | tSTAR arg_value
                    {
                      result = s(:array, s(:splat, val[1]))
                    }

           cases: opt_else | case_body

      opt_rescue: kRESCUE exc_list exc_var then compstmt opt_rescue
                    {
                      klasses, var, body, rest = val[1], val[2], val[4], val[5]

                      klasses ||= s(:array)
                      klasses << node_assign(var, s(:gvar, :"$!")) if var

                      result = new_resbody(klasses, body)
                      result << rest if rest # UGH, rewritten above
                    }
                |
                    {
                      result = nil
                    }

        exc_list: arg_value
                    {
                      result = s(:array, val[0])
                    }
                | mrhs
                | none

         exc_var: tASSOC lhs
                    {
                      result = val
                    }
                | none

      opt_ensure: kENSURE compstmt
                    {
                      result = val
                    }
                | none

         literal: numeric
                | symbol
                | dsym

         strings: string
                    {
                      result = @builder.string_compose(nil, val[0], nil)
                    }

          string: string1
                    {
                      result = [ val[0] ]
                    }
                | string string1
                    {
                      result = val[0] << val[1]
                    }

         string1: tSTRING_BEG string_contents tSTRING_END
                    {
                      result = @builder.string_compose(val[0], val[1], val[2])
                    }
                | tSTRING
                    {
                      result = @builder.string(val[0])
                    }

         xstring: tXSTRING_BEG xstring_contents tSTRING_END
                    {
                      result = @builder.xstring_compose(val[0], val[1], val[2])
                    }

          regexp: tREGEXP_BEG xstring_contents tSTRING_END tREGEXP_OPT
                    {
                      opts   = @builder.regexp_options(val[3])
                      result = @builder.regexp_compose(val[0], val[1], val[2], opts)
                    }

           words: tWORDS_BEG tSPACE tSTRING_END # TODO: unused with Ragel lexer; remove?
                    {
                      result = @builder.words_compose(val[0], [], val[2])
                    }
                | tWORDS_BEG word_list tSTRING_END
                    {
                      result = @builder.words_compose(val[0], val[1], val[2])
                    }

       word_list: # nothing
                    {
                      result = []
                    }
                | word_list word tSPACE
                    {
                      result = val[0] << val[1]
                    }

            word: string_content
                | word string_content # TODO: test this rule, remove if unused
                    {
                      raise "unused 'word string_content'"
                    }

          qwords: tQWORDS_BEG tSPACE tSTRING_END # TODO: unused with Ragel lexer; remove?
                    {
                      result = @builder.words_compose(val[0], [], val[2])
                    }
                | tQWORDS_BEG qword_list tSTRING_END
                    {
                      result = @builder.words_compose(val[0], val[1], val[2])
                    }

      qword_list: # nothing
                    {
                      result = []
                    }
                | qword_list tSTRING_CONTENT tSPACE
                    {
                      result = val[0] << @builder.string(val[1])
                    }

 string_contents: # nothing
                    {
                      result = []
                    }
                | string_contents string_content
                    {
                      result = val[0] << val[1]
                    }

xstring_contents: # nothing # TODO: replace with string_contents?
                    {
                      result = []
                    }
                | xstring_contents string_content
                    {
                      result = val[0] << val[1]
                    }

  string_content: tSTRING_CONTENT
                    {
                      result = @builder.string(val[0])
                    }
                | tSTRING_DVAR string_dvar
                    {
                      result = val[1]
                    }
                | tSTRING_DBEG
                    {
                      #lexer.cond.push false
                      #lexer.cmdarg.push false
                    }
                    compstmt tRCURLY
                    {
                      #lexer.cond.lexpop
                      #lexer.cmdarg.lexpop

                      result = val[2]
                    }

     string_dvar: tGVAR
                    {
                      result = @builder.gvar(val[0])
                    }
                | tIVAR
                    {
                      result = @builder.ivar(val[0])
                    }
                | tCVAR
                    {
                      result = @builder.cvar(val[0])
                    }
                | backref


          symbol: tSYMBOL
                    {
                      if val[0][0].empty?
                        syntax_error(:empty_symbol, val[0])
                      end

                      result = @builder.symbol(val[0])
                    }

            dsym: tSYMBEG xstring_contents tSTRING_END
                    {
                      result = @builder.symbol_compose(val[0], val[1], val[2])
                    }

         numeric: tINTEGER
                    {
                      result = @builder.integer(val[0])
                    }
                | tFLOAT
                    {
                      result = @builder.float(val[0])
                    }
                | tUMINUS_NUM tINTEGER =tLOWEST
                    {
                      result = @builder.integer(val[1], true)
                    }
                | tUMINUS_NUM tFLOAT   =tLOWEST
                    {
                      result = @builder.float(val[1], true)
                    }

        variable: tIDENTIFIER
                    {
                      result = @builder.ident(val[0])
                    }
                | tIVAR
                    {
                      result = @builder.ivar(val[0])
                    }
                | tGVAR
                    {
                      result = @builder.gvar(val[0])
                    }
                | tCVAR
                    {
                      result = @builder.cvar(val[0])
                    }
                | tCONSTANT
                    {
                      result = @builder.const(val[0])
                    }
                | kNIL
                    {
                      result = @builder.nil(val[0])
                    }
                | kSELF
                    {
                      result = @builder.self(val[0])
                    }
                | kTRUE
                    {
                      result = @builder.true(val[0])
                    }
                | kFALSE
                    {
                      result = @builder.false(val[0])
                    }
                | k__FILE__
                    {
                      result = @builder.__FILE__(val[0])
                    }
                | k__LINE__
                    {
                      result = @builder.__LINE__(val[0])
                    }

         var_ref: variable
                    {
                      result = @builder.accessible(val[0])
                    }

         var_lhs: variable
                    {
                      result = @builder.assignable(val[0])
                    }

         backref: tNTH_REF
                    {
                      result = @builder.nth_ref(val[0])
                    }
                | tBACK_REF
                    {
                      result = @builder.back_ref(val[0])
                    }

      superclass: term
                    {
                      result = nil
                    }
                | tLT expr_value term
                    {
                      result = [ val[0], val[1] ]
                    }
                | error term
                    {
                      yyerrok
                      result = nil
                    }

       f_arglist: tLPAREN2 f_args opt_nl tRPAREN
                    {
                      result = val[1]
                      @lexer.state = :expr_beg
                    }
                | f_args term
                    {
                      result = val[0]
                    }

          f_args: f_arg tCOMMA f_optarg tCOMMA f_rest_arg opt_f_block_arg
                    {
                      result = @builder.args(val[0], val[2], val[4], val[5])
                    }
                | f_arg tCOMMA f_optarg                   opt_f_block_arg
                    {
                      result = @builder.args(val[0], val[2], [], val[3])
                    }
                | f_arg tCOMMA                 f_rest_arg opt_f_block_arg
                    {
                      result = @builder.args(val[0], [], val[2], val[3])
                    }
                | f_arg                                   opt_f_block_arg
                    {
                      result = @builder.args(val[0], [], [], val[1])
                    }
                |              f_optarg tCOMMA f_rest_arg opt_f_block_arg
                    {
                      result = @builder.args([], val[0], val[2], val[3])
                    }
                |              f_optarg                   opt_f_block_arg
                    {
                      result = @builder.args([], val[0], [], val[1])
                    }
                |                              f_rest_arg opt_f_block_arg
                    {
                      result = @builder.args([], [], val[0], val[1])
                    }
                |                                             f_block_arg
                    {
                      result = @builder.args([], [], [], [ val[0] ])
                    }
                | none
                    {
                      result = @builder.args([], [], [], [])
                    }

      f_norm_arg: tCONSTANT
                    {
                      syntax_error(:argument_const, val[0])
                    }
                | tIVAR
                    {
                      syntax_error(:argument_ivar, val[0])
                    }
                | tGVAR
                    {
                      syntax_error(:argument_gvar, val[0])
                    }
                | tCVAR
                    {
                      syntax_error(:argument_cvar, val[0])
                    }
                | tIDENTIFIER
                    {
                      @static_env.declare val[0][0]

                      result = @builder.arg(val[0])
                    }

           f_arg: f_norm_arg
                    {
                      result = [ val[0] ]
                    }
                | f_arg tCOMMA f_norm_arg
                    {
                      result = val[0] << val[2]
                    }

           f_opt: tIDENTIFIER tEQL arg_value
                    {
                      @static_env.declare val[0][0]

                      result = @builder.optarg(val[0], val[1], val[2])
                    }

        f_optarg: f_opt
                    {
                      result = [ val[0] ]
                    }
                | f_optarg tCOMMA f_opt
                    {
                      result = val[0] << val[2]
                    }

    restarg_mark: tSTAR2 | tSTAR

      f_rest_arg: restarg_mark tIDENTIFIER
                    {
                      @static_env.declare val[1][0]

                      result = [ @builder.splatarg(val[0], val[1]) ]
                    }
                | restarg_mark
                    {
                      result = [ @builder.splatarg(val[0]) ]
                    }

     blkarg_mark: tAMPER2 | tAMPER

     f_block_arg: blkarg_mark tIDENTIFIER
                    {
                      @static_env.declare val[1][0]

                      result = @builder.blockarg(val[0], val[1])
                    }

 opt_f_block_arg: tCOMMA f_block_arg
                    {
                      result = [ val[1] ]
                    }
                | # nothing
                    {
                      result = []
                    }

       singleton: var_ref
                | tLPAREN2 expr opt_nl tRPAREN
                    {
                      result = val[1]
                    }

      assoc_list: none
                    {
                      result = []
                    }
                | assocs trailer
                    {
                      result = val[0]
                    }
                | args trailer
                    {
                      result = @builder.pair_list_18(val[0])
                    }

          assocs: assoc
                    {
                      result = [ val[0] ]
                    }
                | assocs tCOMMA assoc
                    {
                      result = val[0] << val[2]
                    }

           assoc: arg_value tASSOC arg_value
                    {
                      result = @builder.pair(val[0], val[1], val[2])
                    }

       operation: tIDENTIFIER | tCONSTANT | tFID
      operation2: tIDENTIFIER | tCONSTANT | tFID | op
      operation3: tIDENTIFIER | tFID | op
    dot_or_colon: tDOT | tCOLON2
       opt_terms:  | terms
          opt_nl:  | tNL
         trailer:  | tNL | tCOMMA

            term: tSEMI
                    {
                      yyerrok
                    }
                | tNL

           terms: term
                | terms tSEMI

            none: # nothing
                    {
                      result = nil
                    }

end

---- header

require 'parser'

---- inner

  def version
    18
  end
