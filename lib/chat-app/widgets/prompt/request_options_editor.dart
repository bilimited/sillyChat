import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:get/get.dart';
import '../../utils/RequestOptions.dart';


class RequestOptionsEditor extends StatefulWidget {
  final LLMRequestOptions options;
  final ValueChanged<LLMRequestOptions> onChanged;

  const RequestOptionsEditor({
    Key? key,
    required this.options,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<RequestOptionsEditor> createState() => _RequestOptionsEditorState();
}

class _RequestOptionsEditorState extends State<RequestOptionsEditor> {
  late final TextEditingController _maxTokensController;
  late final TextEditingController _maxHistoryLengthController;
  final VaultSettingController vaultSettingController = Get.find();

  @override
  void initState() {
    super.initState();
    _maxTokensController =
        TextEditingController(text: widget.options.maxTokens.toString());
    _maxHistoryLengthController =
        TextEditingController(text: widget.options.maxHistoryLength.toString());
  }

  @override
  void dispose() {
    _maxTokensController.dispose();
    _maxHistoryLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSlider(
          label: '温度 (Temperature)',
          value: widget.options.temperature,
          max: 2.0,
          onChanged: (value) =>
              widget.onChanged(widget.options.copyWith(temperature: value)),
        ),
        _buildSlider(
          label: '核采样 (Top P)',
          value: widget.options.topP,
          onChanged: (value) =>
              widget.onChanged(widget.options.copyWith(topP: value)),
        ),
        _buildSlider(
          label: '话题新鲜度惩罚 (Presence Penalty)',
          value: widget.options.presencePenalty,
          min: -1.0,
          max: 1.5,
          onChanged: (value) =>
              widget.onChanged(widget.options.copyWith(presencePenalty: value)),
        ),
        _buildSlider(
          label: '词频惩罚 (Frequency Penalty)',
          value: widget.options.frequencyPenalty,
          min: -1.0,
          max: 1.5,
          onChanged: (value) => widget
              .onChanged(widget.options.copyWith(frequencyPenalty: value)),
        ),
        _buildNumberInput(
          label: 'Token上限',
          controller: _maxTokensController,
          onChanged: (value) {
            final intValue = int.tryParse(value);
            if (intValue != null) {
              widget.onChanged(widget.options.copyWith(maxTokens: intValue));
            }
          },
        ),
        _buildNumberInput(
          label: '历史消息长度上限',
          controller: _maxHistoryLengthController,
          onChanged: (value) {
            final intValue = int.tryParse(value);
            if (intValue != null) {
              widget.onChanged(
                  widget.options.copyWith(maxHistoryLength: intValue));
            }
          },
        ),
        _buildCheckbox(
          label: '是否删除思考消息',
          value: widget.options.isDeleteThinking,
          onChanged: (value) {
            widget.onChanged(widget.options.copyWith(isDeleteThinking: value));
          },
        ),
        const SizedBox(height: 16),
        _buildApiSelector(),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0.0,
    double max = 1.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Row(
            children: [
                Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: ((max - min) / 0.1).round(),
                  onChanged: onChanged,
                ),
              ),
              SizedBox(width: 50, child: Text(value.toStringAsFixed(2))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInput({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: onChanged,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('模型API'),
        const SizedBox(height: 8),
        Obx(() {
          final apis = vaultSettingController.apis;
          int? selectedApiId;


          selectedApiId = vaultSettingController.getApiById(widget.options.apiId)?.id;
          // if(selectedApiId==null && apis.length>0){
          //   selectedApiId = apis[0].id;
          //   widget.onChanged(widget.options.copyWith(apiId: selectedApiId));
          // }
          return DropdownButtonFormField<int>(
            value: selectedApiId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            hint: const Text('请选择API'),
            items: apis.map((api) {
              return DropdownMenuItem<int>(
                value: api.id,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 250),
                  child: Text(
                  '${api.displayName} (${api.modelName})',
                  overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
            onChanged: (int? value) {
              if (value != null) {
                widget.onChanged(widget.options.copyWith(apiId: value));
              }
            },
          );
        }),
      ],
    );
  }

  Widget _buildCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
        ),
        Text(label),
      ],
    );

  }
}
